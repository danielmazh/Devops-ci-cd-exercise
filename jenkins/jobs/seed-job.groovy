// =============================================================================
// Jenkins Job DSL - Seed Job
// =============================================================================
// Creates all pipeline jobs programmatically
// Run this seed job to generate/update all pipeline configurations
// =============================================================================

// -----------------------------------------------------------------------------
// Configuration
// -----------------------------------------------------------------------------
def githubOrg = 'danielmazh'
def githubRepo = 'devops-ci-cd-exercise'
def githubCredentialsId = 'github-credentials'

// -----------------------------------------------------------------------------
// Main Pipeline Job
// -----------------------------------------------------------------------------
pipelineJob('devops-testing-app') {
    displayName('DevOps Testing App - Main Pipeline')
    
    description('''
        <h3>Main CI/CD Pipeline</h3>
        <p>Automated pipeline for DevOps Testing Application</p>
        <ul>
            <li>✅ Unit Tests</li>
            <li>✅ Integration Tests</li>
            <li>✅ E2E Tests</li>
            <li>✅ Code Coverage</li>
            <li>✅ Docker Build & Push</li>
            <li>✅ AWS Deployment</li>
            <li>✅ JIRA Integration</li>
        </ul>
    ''')
    
    // Keep last 10 builds
    logRotator {
        numToKeep(10)
        artifactNumToKeep(5)
    }
    
    // Pipeline definition from SCM
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url("https://github.com/${githubOrg}/${githubRepo}.git")
                        credentials(githubCredentialsId)
                    }
                    branches('*/main', '*/develop', '*/feature/*')
                }
            }
            scriptPath('jenkins/Jenkinsfile')
            lightweight(true)
        }
    }
    
    // Triggers
    triggers {
        githubPush()
        pollSCM('H/5 * * * *')
    }
    
    // Properties
    properties {
        disableConcurrentBuilds()
        
        githubProjectUrl("https://github.com/${githubOrg}/${githubRepo}")
    }
}

// -----------------------------------------------------------------------------
// Production Release Pipeline
// -----------------------------------------------------------------------------
pipelineJob('devops-testing-app-production') {
    displayName('DevOps Testing App - Production Release')
    
    description('''
        <h3>Production Release Pipeline</h3>
        <p>Production deployment with approval gates</p>
        <ul>
            <li>🔒 Manual approval required</li>
            <li>🚀 Full test suite</li>
            <li>↩️ Rollback capability</li>
            <li>📧 Notification alerts</li>
        </ul>
    ''')
    
    // Keep last 5 builds
    logRotator {
        numToKeep(5)
        artifactNumToKeep(3)
    }
    
    // Parameters
    parameters {
        booleanParam('SKIP_TESTS', false, 'Skip test execution (use with caution!)')
        booleanParam('RUN_PERFORMANCE_TESTS', true, 'Run performance tests')
        stringParam('ROLLBACK_VERSION', '', 'Version to rollback to (leave empty for normal deployment)')
    }
    
    // Pipeline definition from SCM
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url("https://github.com/${githubOrg}/${githubRepo}.git")
                        credentials(githubCredentialsId)
                    }
                    branches('*/main', '*/release/*')
                    extensions {
                        cloneOptions {
                            shallow(true)
                            depth(1)
                        }
                    }
                }
            }
            scriptPath('jenkins/Jenkinsfile.prod')
            lightweight(true)
        }
    }
    
    // Properties
    properties {
        disableConcurrentBuilds()
    }
}

// -----------------------------------------------------------------------------
// Nightly Build Job (Optional)
// -----------------------------------------------------------------------------
pipelineJob('devops-testing-app-nightly') {
    displayName('DevOps Testing App - Nightly Build')
    
    description('''
        <h3>Nightly Build</h3>
        <p>Full test suite including performance tests</p>
    ''')
    
    logRotator {
        numToKeep(7)
    }
    
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url("https://github.com/${githubOrg}/${githubRepo}.git")
                        credentials(githubCredentialsId)
                    }
                    branches('*/main')
                }
            }
            scriptPath('jenkins/Jenkinsfile')
            lightweight(true)
        }
    }
    
    triggers {
        cron('H 2 * * *')  // Run at 2 AM every day
    }
    
    // Environment variable to enable performance tests
    environmentVariables {
        env('RUN_PERFORMANCE_TESTS', 'true')
        env('ENVIRONMENT', 'nightly')
    }
}

// -----------------------------------------------------------------------------
// Folder for organizing jobs (optional)
// -----------------------------------------------------------------------------
folder('devops-testing-app-folder') {
    displayName('DevOps Testing App')
    description('All jobs related to DevOps Testing Application')
}

// -----------------------------------------------------------------------------
// View for dashboard
// -----------------------------------------------------------------------------
listView('DevOps Pipelines') {
    description('All DevOps Testing App pipelines')
    
    jobs {
        regex('devops-testing-app.*')
    }
    
    columns {
        status()
        weather()
        name()
        lastSuccess()
        lastFailure()
        lastDuration()
        buildButton()
    }
}

// Print completion message
println """
============================================
Job DSL Seed Completed!
============================================
Created jobs:
  - devops-testing-app (Main Pipeline)
  - devops-testing-app-production (Production Release)
  - devops-testing-app-nightly (Nightly Build)

Created views:
  - DevOps Pipelines
============================================
"""
