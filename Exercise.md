
# DevOps Exercise - Lesson 47

## Tasks

### 1. Docker Setup
- Create a `Dockerfile` in the `docker/` folder with all dependencies required to run the application
- Include all necessary configuration files for the Docker container environment

### 2. Jenkins Pipeline Enhancement
- **Testing Phase:**
    - Run all tests (unit, integration, e2e) - mandatory to pass
    - Skip performance tests except in production environment
    - Generate code coverage reports to `htmlcov/` directory

- **Build & Artifact Creation:**
    - Upon successful tests: create version tag and build Docker image
    - Push Docker image artifact to Docker Hub
    - Proceed to CD stage: Deploy to AWS staging using Terraform + Ansible

- **Failure Handling:**
    - Create JIRA issue on pipeline failure
    - Send email notifications with build details:
        - Build number
        - Branch name
        - Duration
        - Failed stage
        - Build URL link
    - Optional: Slack notification integration

- **Test Reports Integration:**
    - Configure Jenkins to display test reports
    - Include detailed issue reports from test failures
    - Archive coverage reports in Jenkins UI

### 3. Documentation
- Capture screenshot of successful pipeline execution
- Capture screenshot of failed pipeline execution
- Add both images to the project documentation
