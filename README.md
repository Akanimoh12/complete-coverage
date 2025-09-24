![alt text](<Screenshot from 2025-09-24 05-27-45.png>)

## Added More Tests

I wrote more test cases to get 100% coverage. Here's what I added:

- Tests for getting rewards when you have some and when you don't
- Edge case tests for when no one has staked yet
- Tests for when reward periods end and new ones start
- Tests for the view functions like `earned()` and `rewardPerToken()`

Now all 16 tests pass and everything is covered.