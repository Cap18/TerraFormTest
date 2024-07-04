### Infrastructure Components

1. **VPC (Virtual Private Cloud):** Provides network isolation.
2. **Subnets:** Ensures high availability by distributing resources across multiple availability zones.
3. **Internet Gateway and NAT Gateway:** Allows public internet access for public subnets and secure outbound internet access for private subnets.
4. **Security Groups:** Manages inbound and outbound traffic.
5. **Application Load Balancer (ALB):** Distributes incoming traffic across multiple instances.
6. **Auto Scaling Group (ASG) with EC2 Instances:** Ensures high availability and scalability.
7. **RDS (Relational Database Service):** Manages database with multi-AZ deployment for high availability.
8. **CloudWatch:** Monitors and logs infrastructure performance.
9. **IAM Roles and Policies:** Ensures secure access management.
10. **S3 Bucket:** Stores logs and backups.

### Explanation

1. **VPC Module:** Uses a Terraform module to create a VPC with public and private subnets, enabling high availability across multiple AZs.
2. **Security Groups:** Defines security groups for ALB and EC2 instances to manage network traffic securely.
3. **Application Load Balancer:** Provides high availability and distributes incoming traffic across multiple instances.
4. **Auto Scaling Group and Launch Configuration:** Ensures the application scales automatically based on demand.
5. **RDS:** Uses Amazon RDS for a highly available, managed MySQL database.
6. **IAM Roles and Policies:** Assigns roles and policies to EC2 instances for secure access to resources.
7. **CloudWatch Log Group:** Configures CloudWatch for monitoring and logging.
8. **S3 Bucket:** Stores logs and backups securely.

### Best Practices

- **Modularity:** Uses modules to keep the code organized and reusable.
- **Tags:** Tags resources for better management and cost allocation.
- **Security:** Applies the principle of least privilege with IAM roles and policies, restricts security group access.
- **High Availability:** Distributes resources
