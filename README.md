1. create s3 bucket
    - Name: burns-terraform-state-bucket
    - Block all public access
    - Enable versioning
    - Enable encryption
3. Create DynamoDB table
    - Name: terraform_state_lockid
    - Partition key: LockID
2. configure backend in backend.tf to store state files in s3 bucket

note: when using cursorai terminal:
- Add AWS CLI to PATH in Cursor's terminal session:
```$env:Path += ";C:\Program Files\Amazon\AWSCLIV2"```
- Add Terraform to the PATH environment variables in Cursor's terminal:
```$env:Path += ";C:\terraform"```