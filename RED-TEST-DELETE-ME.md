# RED TEST - negative control for the secret-scan gate

This file deliberately contains a FAKE, non-functional AWS access key id (AWS's own
public documentation example, not a real credential) to prove the required
`secret-scan` check goes RED and blocks the merge. This branch is throwaway and
gets deleted immediately after the check fails.

AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
