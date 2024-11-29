;; Smart Savings - A decentralized savings goal manager
;; Description: Manages multiple savings goals with automated features and multi-sig capabilities

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-goal-not-found (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-deadline-passed (err u104))
(define-constant err-time-lock (err u105))
(define-constant err-invalid-amount (err u106))

;; Data Variables
(define-data-var yield-rate uint u400) ;; 4.00% represented as u400
(define-data-var next-goal-id uint u1)

;; Data Maps
(define-map SavingsGoals
    { goal-id: uint }
    {
        owner: principal,
        target-amount: uint,
        current-amount: uint,
        deadline: uint,
        time-lock: uint,
        is-multi-sig: bool,
        is-emergency-fund: bool,
        last-deposit: uint,
        created-at: uint,
        yield-enabled: bool
    }
)

(define-map GoalContributors
    { goal-id: uint, contributor: principal }
    { authorized: bool }
)

(define-map GoalWithdrawals
    { goal-id: uint }
    {
        requested-by: principal,
        amount: uint,
        requested-at: uint,
        approved-by: (optional principal)
    }
)

;; Private Functions
(define-private (is-owner (goal-id uint))
    (let ((goal (map-get? SavingsGoals { goal-id: goal-id })))
        (match goal
            goal-data (is-eq (get owner goal-data) tx-sender)
            false
        )
    )
)

(define-private (calculate-yield (amount uint) (time uint))
    (let (
        (rate (var-get yield-rate))
        (time-factor (/ time u31536000)) ;; Convert seconds to years
    )
        (/ (* amount (* rate time-factor)) u10000)
    )
)

;; Public Functions

;; Create a new savings goal
(define-public (create-goal (target-amount uint) (deadline uint) (time-lock uint) (is-multi-sig bool) (is-emergency bool) (yield-enabled bool))
    (let (
        (goal-id (var-get next-goal-id))
        (current-block-height block-height)
    )
        (asserts! (> target-amount u0) err-invalid-amount)
        (asserts! (> deadline current-block-height) err-deadline-passed)
        
        (map-set SavingsGoals
            { goal-id: goal-id }
            {
                owner: tx-sender,
                target-amount: target-amount,
                current-amount: u0,
                deadline: deadline,
                time-lock: time-lock,
                is-multi-sig: is-multi-sig,
                is-emergency-fund: is-emergency,
                last-deposit: current-block-height,
                created-at: current-block-height,
                yield-enabled: yield-enabled
            }
        )
        
        ;; Authorize owner as contributor
        (map-set GoalContributors
            { goal-id: goal-id, contributor: tx-sender }
            { authorized: true }
        )

        ;; Increment the goal ID counter
        (var-set next-goal-id (+ goal-id u1))
        
        (ok goal-id)
    )
)

;; Add a contributor to a multi-sig goal
(define-public (add-contributor (goal-id uint) (contributor principal))
    (let ((goal (unwrap! (map-get? SavingsGoals { goal-id: goal-id }) err-goal-not-found)))
        (asserts! (is-owner goal-id) err-unauthorized)
        (asserts! (get is-multi-sig goal) err-unauthorized)
        
        (map-set GoalContributors
            { goal-id: goal-id, contributor: contributor }
            { authorized: true }
        )
        (ok true)
    )
)

;; Make a deposit to a goal
(define-public (deposit (goal-id uint) (amount uint))
    (let (
        (goal (unwrap! (map-get? SavingsGoals { goal-id: goal-id }) err-goal-not-found))
        (contributor-status (default-to { authorized: false }
            (map-get? GoalContributors { goal-id: goal-id, contributor: tx-sender })))
    )
        (asserts! (get authorized contributor-status) err-unauthorized)
        (asserts! (> amount u0) err-invalid-amount)
        
        ;; Transfer STX from sender to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update goal amount
        (map-set SavingsGoals
            { goal-id: goal-id }
            (merge goal {
                current-amount: (+ (get current-amount goal) amount),
                last-deposit: block-height
            })
        )
        
        (ok true)
    )
)

;; Request a withdrawal
(define-public (request-withdrawal (goal-id uint) (amount uint))
    (let (
        (goal (unwrap! (map-get? SavingsGoals { goal-id: goal-id }) err-goal-not-found))
        (current-time block-height)
    )
        (asserts! (is-owner goal-id) err-unauthorized)
        (asserts! (<= amount (get current-amount goal)) err-insufficient-balance)
        
        ;; Check time lock
        (asserts! (>= current-time (+ (get last-deposit goal) (get time-lock goal))) err-time-lock)
        
        (if (get is-multi-sig goal)
            ;; Create withdrawal request for multi-sig
            (begin
                (map-set GoalWithdrawals
                    { goal-id: goal-id }
                    {
                        requested-by: tx-sender,
                        amount: amount,
                        requested-at: current-time,
                        approved-by: none
                    }
                )
                (ok true)
            )
            ;; Process immediate withdrawal for single-sig
            (process-withdrawal goal-id amount)
        )
    )
)

;; Approve and process a multi-sig withdrawal
(define-public (approve-withdrawal (goal-id uint))
    (let (
        (goal (unwrap! (map-get? SavingsGoals { goal-id: goal-id }) err-goal-not-found))
        (withdrawal (unwrap! (map-get? GoalWithdrawals { goal-id: goal-id }) err-goal-not-found))
        (contributor-status (default-to { authorized: false }
            (map-get? GoalContributors { goal-id: goal-id, contributor: tx-sender })))
    )
        (asserts! (get authorized contributor-status) err-unauthorized)
        (asserts! (not (is-eq tx-sender (get requested-by withdrawal))) err-unauthorized)
        
        (process-withdrawal goal-id (get amount withdrawal))
    )
)

;; Process withdrawal (private function)
(define-private (process-withdrawal (goal-id uint) (amount uint))
    (let ((goal (unwrap! (map-get? SavingsGoals { goal-id: goal-id }) err-goal-not-found)))
        ;; Transfer STX from contract to owner
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) (get owner goal))))
        
        ;; Update goal amount
        (map-set SavingsGoals
            { goal-id: goal-id }
            (merge goal {
                current-amount: (- (get current-amount goal) amount)
            })
        )
        
        (ok true)
    )
)

;; Calculate and add yield (can be called periodically)
(define-public (add-yield (goal-id uint))
    (let (
        (goal (unwrap! (map-get? SavingsGoals { goal-id: goal-id }) err-goal-not-found))
        (yield-amount (calculate-yield
            (get current-amount goal)
            (- block-height (get last-deposit goal))
        ))
    )
        (asserts! (get yield-enabled goal) err-unauthorized)
        
        (map-set SavingsGoals
            { goal-id: goal-id }
            (merge goal {
                current-amount: (+ (get current-amount goal) yield-amount),
                last-deposit: block-height
            })
        )
        
        (ok yield-amount)
    )
)

;; Getter Functions
(define-read-only (get-goal-details (goal-id uint))
    (map-get? SavingsGoals { goal-id: goal-id })
)

(define-read-only (get-withdrawal-request (goal-id uint))
    (map-get? GoalWithdrawals { goal-id: goal-id })
)

(define-read-only (is-contributor (goal-id uint) (contributor principal))
    (default-to
        { authorized: false }
        (map-get? GoalContributors { goal-id: goal-id, contributor: contributor })
    )
)

;; Admin Functions
(define-public (update-yield-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set yield-rate new-rate)
        (ok true)
    )
)