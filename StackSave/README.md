# Smart Savings - Decentralized Savings Goal Manager

**Smart Savings** is a decentralized savings goal manager built on the Stacks blockchain. It allows users to create and manage multiple savings goals with automated features such as yield accrual, multi-signature contributions, and time-locked withdrawals. This smart contract empowers users to save for specific targets while enabling collaborative contributions, automated yield generation, and robust withdrawal conditions.

The contract ensures secure management of savings goals, with each goal having a unique ID and associated features such as deadlines, time-locks, multi-signature authorization, and emergency fund status.

## Key Features

1. **Savings Goals Management**: Users can create and manage individual savings goals, specifying target amounts, deadlines, time-locks, and whether the goal is a multi-signature or emergency fund.
   
2. **Multi-Signature Support**: Multiple contributors can be added to a goal. In case of multi-signature goals, withdrawals require authorization from multiple contributors before they can be executed.

3. **Automated Yield Generation**: The contract supports automated yield generation for savings goals. The yield is calculated based on the amount saved and the time elapsed since the last deposit. The yield rate can be adjusted by the contract owner.

4. **Time-Locked Withdrawals**: Users can set a time-lock period during which no withdrawals can be made after a deposit. This ensures that the savings remain untouched until the specified time-lock period expires.

5. **Withdrawal Requests**: Users can request withdrawals, which may be approved or rejected based on conditions such as the goal’s status and multi-signature requirements.

6. **Emergency Fund**: A savings goal can be marked as an emergency fund, providing special conditions for withdrawals in times of need.

7. **Owner Permissions**: The contract owner (typically the deployer) has administrative control, including the ability to update the yield rate applied to savings goals.

## Contract Structure

The contract uses several data structures to manage goals, contributors, and withdrawals:

- **SavingsGoals**: A map to store details about each savings goal, including the owner, target amount, current amount, deadline, time-lock, multi-signature status, and yield enabled status.
- **GoalContributors**: A map to store contributors to each goal, with their authorization status (i.e., whether they can contribute or withdraw).
- **GoalWithdrawals**: A map to store withdrawal requests, including the requested amount and the approval status of the withdrawal.
  
### Constants

- `contract-owner`: The principal address of the contract owner (admin).
- `err-*`: Error codes for various contract exceptions.

### Data Variables

- `yield-rate`: The interest rate applied to savings goals to calculate yield (stored as an integer percentage, e.g., 400 = 4%).
- `next-goal-id`: The next available unique identifier for a new savings goal.

### Maps

- **SavingsGoals**: Stores the details of each savings goal.
- **GoalContributors**: Stores the contributors to each savings goal.
- **GoalWithdrawals**: Stores withdrawal requests for each savings goal.

## Functions

### Public Functions

1. **`create-goal`**: Creates a new savings goal with the specified parameters (target amount, deadline, time-lock, multi-sig status, and emergency fund status).
   - **Parameters**:
     - `target-amount`: The amount to be saved for the goal.
     - `deadline`: The deadline by which the goal should be achieved (block height).
     - `time-lock`: The time-lock period (in blocks) that prevents withdrawals before the specified period.
     - `is-multi-sig`: Boolean indicating whether the goal requires multiple signatures for withdrawal.
     - `is-emergency`: Boolean indicating whether the goal is an emergency fund.
     - `yield-enabled`: Boolean indicating whether yield is enabled for this goal.
   - **Returns**: The unique ID of the created savings goal.

2. **`add-contributor`**: Adds a contributor to a multi-signature savings goal.
   - **Parameters**:
     - `goal-id`: The ID of the savings goal.
     - `contributor`: The principal address of the contributor to be added.
   - **Returns**: `true` if the contributor is successfully added.

3. **`deposit`**: Makes a deposit to an existing savings goal.
   - **Parameters**:
     - `goal-id`: The ID of the savings goal.
     - `amount`: The amount to be deposited (in STX).
   - **Returns**: `true` if the deposit is successfully made.

4. **`request-withdrawal`**: Requests a withdrawal from a savings goal.
   - **Parameters**:
     - `goal-id`: The ID of the savings goal.
     - `amount`: The amount to be withdrawn.
   - **Returns**: `true` if the withdrawal request is successfully created.

5. **`approve-withdrawal`**: Approves a withdrawal request for a multi-signature goal.
   - **Parameters**:
     - `goal-id`: The ID of the savings goal.
   - **Returns**: `true` if the withdrawal is successfully approved.

6. **`add-yield`**: Adds yield to a savings goal based on the current balance and the time elapsed since the last deposit.
   - **Parameters**:
     - `goal-id`: The ID of the savings goal.
   - **Returns**: The amount of yield added to the goal.

7. **`update-yield-rate`**: Allows the contract owner to update the global yield rate for savings goals.
   - **Parameters**:
     - `new-rate`: The new yield rate (in percentage).
   - **Returns**: `true` if the yield rate is successfully updated.

### Private Functions

- **`is-owner`**: Checks if the caller is the owner of a specific savings goal.
- **`calculate-yield`**: Calculates the yield for a savings goal based on the deposited amount and elapsed time.
- **`process-withdrawal`**: Handles the withdrawal process, transferring funds from the contract to the owner and updating the savings goal.

### Getter Functions

- **`get-goal-details`**: Retrieves the details of a savings goal.
- **`get-withdrawal-request`**: Retrieves the withdrawal request for a specific goal.
- **`is-contributor`**: Checks if a given principal is authorized to contribute to a specific goal.

## Error Codes

- **`err-owner-only`**: The caller must be the contract owner.
- **`err-insufficient-balance`**: The requested withdrawal amount exceeds the available balance.
- **`err-goal-not-found`**: The specified savings goal does not exist.
- **`err-unauthorized`**: The caller is not authorized to perform the action.
- **`err-deadline-passed`**: The deadline for the goal has already passed.
- **`err-time-lock`**: The withdrawal is attempted before the time-lock period has expired.
- **`err-invalid-amount`**: The amount specified is invalid (e.g., zero or negative).

## Security Considerations

- **Multi-Signature**: For multi-signature goals, a withdrawal cannot be made unless the required number of contributors approve it, ensuring greater security for collective savings.
- **Time-Lock**: The time-lock feature ensures that users cannot withdraw their savings prematurely, which helps enforce long-term savings goals.
- **Owner Permissions**: The contract owner has the ability to update the yield rate, which should be managed carefully to avoid abuse or drastic changes that could impact users.

Smart Savings provides a powerful framework for decentralized savings with automated yield generation, multi-signature contributions, and time-lock protections. By using this contract, users can efficiently manage their savings goals while ensuring security, collaboration, and growth over time.