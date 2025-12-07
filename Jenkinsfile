pipeline {
    agent any
    
    tools {
        maven 'maven-3.8.8'  // Assurez-vous que ce nom correspond à votre config Jenkins
    }
    
    environment {
        DEPLOY_ENV = "${env.BRANCH_NAME == 'main' ? 'prod' : (env.BRANCH_NAME == 'staging' ? 'staging' : 'dev')}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build & Deploy (CloudHub 2.0)') {
            steps {
                script {
                    def anypointCredId = 'anypoint_credentials'

                    withCredentials([
                        usernamePassword(
                            credentialsId: anypointCredId,
                            usernameVariable: 'CLIENT_ID',
                            passwordVariable: 'CLIENT_SECRET'
                        )
                    ]) {
                        withMaven(maven: 'maven-3.8.8', publisherStrategy: 'EXPLICIT') {

                            // settings.xml pour anypoint-exchange-v3
                    sh '''
                        mkdir -p ~/.m2
                        cat > ~/.m2/settings.xml <<XMLEOF
<?xml version="1.0"?>
<settings>
  <pluginGroups>
      <pluginGroup>org.mule.tools</pluginGroup>
  </pluginGroups>
  <servers>
    <server>
      <id>anypoint-exchange-v3</id>
      <username>~~~Client~~~</username>
      <password>${CLIENT_ID}~?~${CLIENT_SECRET}</password>
    </server>
  </servers>
</settings>
XMLEOF
                    '''

                            if (env.DEPLOY_ENV == 'dev') {
                                echo "🌍 Déploiement DEV avec tests (env=${env.DEPLOY_ENV})"

                                sh """
                                    mvn clean deploy \
                                        -Denv=${DEPLOY_ENV} \
                                        -DmuleDeploy \
                                        -Dclient.id=\${CLIENT_ID} \
                                        -Dclient.secret=\${CLIENT_SECRET}
                                """
                            } else {
                                echo "🌍 Déploiement ${env.DEPLOY_ENV} en mode CI (-Pci, sans tests)"

                                sh """
                                    mvn clean deploy \
                                        -Denv=${DEPLOY_ENV} \
                                        -Pci \
                                        -DmuleDeploy \
                                        -Dclient.id=\${CLIENT_ID} \
                                        -Dclient.secret=\${CLIENT_SECRET}
                                """
                            }
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Déploiement réussi !'
        }
        failure {
            echo '❌ Le déploiement a échoué.'
        }
        always {
            cleanWs()  // Nettoie le workspace après le build
        }
    }
}