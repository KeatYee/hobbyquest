# Password Reset Functional and Integration Test Cases

These cases extend the combined functional and integration test table.

| Test Case ID | Preconditions | Steps | Expected Results |
|---|---|---|---|
| FI-041 – Forgot password from Login | A Firebase email/password account exists and the user is signed out. The device has internet access. | 1. Open Login.<br>2. Select **Forgot Password?**.<br>3. Enter the account email.<br>4. Select **Send Link**.<br>5. Open the reset email and set a new password.<br>6. Sign in with the new password. | A neutral success message is displayed without revealing whether the account exists. Firebase sends one reset email. The reset link allows a new password to be saved. The old password no longer signs in and the new password succeeds. |
| FI-042 – Invalid reset email | The user is on Login. | 1. Select **Forgot Password?**.<br>2. Leave the email empty and attempt to continue.<br>3. Enter a malformed email and attempt to continue. | Inline validation prevents submission. No Firebase password-reset request is sent. |
| FI-043 – Reset password from Profile | An email-based user is authenticated and viewing Profile. | 1. Select **Reset Password**.<br>2. Confirm **Send Link**.<br>3. Check the signed-in account’s inbox.<br>4. Follow the link and set a new password. | The reset request is sent to the authenticated user’s email. A success message is displayed. After resetting and signing out, the user can sign in with the new password. |
| FI-044 – Password reset service failure | Login or Profile is open. A network failure or Firebase rate limit can be simulated safely. | 1. Attempt to send a reset email while offline.<br>2. Reconnect and send repeated requests until the test environment returns a rate-limit error. | Network and rate-limit errors produce clear messages. The application remains responsive, does not navigate incorrectly, and allows a later retry. |
