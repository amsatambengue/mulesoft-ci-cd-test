pipeline {
  agent any

  tools {
    maven 'maven-3.8.8'
    jdk 'jdk-17'
  }

  stages {
  
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

  stage('Set Environment') {
    steps {
        script {
            echo "Branche détectée : ${env.BRANCH_NAME}"
            
            // Configuration par environnement (approche Map - plus maintenable)
            def envConfig = [
                'develop': [
                    deployEnv: 'development',
                    sizingProfile: 'dev-sizing'
                ],
                'release': [
                    deployEnv: 'test',
                    sizingProfile: 'test-sizing'
                ],
                'main': [
                    deployEnv: 'production',
                    sizingProfile: 'prod-sizing'
                ]
            ]
            
            // Déterminer la clé de configuration
            def configKey = ''
            if (env.BRANCH_NAME == 'develop') {
                configKey = 'develop'
            } else if (env.BRANCH_NAME.startsWith('release/')) {
                configKey = 'release'
            } else if (env.BRANCH_NAME == 'main') {
                configKey = 'main'
            } else {
                error "❌ Branche [${env.BRANCH_NAME}] non gérée pour déploiement CI/CD"
            }
            
            // Récupérer la configuration
            def config = envConfig[configKey]
            
            // Assigner aux variables d'environnement
            env.DEPLOY_ENV      = config.deployEnv
            env.SIZING_PROFILE  = config.sizingProfile
            env.MAVEN_SETTINGS  = 'maven-settings-file'
            env.ACTIVE_PROFILES = "ci,${config.sizingProfile}"  
            
            // Affichage des informations
            echo """
            ════════════════════════════════════════════════════════════
            📌 Configuration du Pipeline
            ════════════════════════════════════════════════════════════
            🌿 Branche               : ${env.BRANCH_NAME}
            🌍 Environnement         : ${env.DEPLOY_ENV}
            📦 Sizing Profile        : ${env.SIZING_PROFILE}
            📋 Maven Settings        : ${env.MAVEN_SETTINGS}
            🔧 Profils Maven actifs  : ${env.ACTIVE_PROFILES}
            ════════════════════════════════════════════════════════════
            """
        }
    }
}

  stage('Build, Deploy to Development/UAT') {
      when {
      expression { return env.DEPLOY_ENV == 'development' || env.DEPLOY_ENV == 'test' }
    }
      steps {
          script {
              def nexusCredId = 'nexus-releases'
              def anypointCredId = "anypoint-connected-app-${env.DEPLOY_ENV}"
                            
              withCredentials([
                  // NEXUS
                  usernamePassword(
                      credentialsId: nexusCredId, 
                      usernameVariable: 'NEXUS_USER',      
                      passwordVariable: 'NEXUS_PWD'       
                  ),
                  // ANYPOINT PLATFORM
                  usernamePassword(
                      credentialsId: anypointCredId, 
                      usernameVariable: 'CLIENT_ID',       
                      passwordVariable: 'CLIENT_SECRET'    
                  )
              ]) {
                  configFileProvider([
                      configFile(
                          fileId: env.MAVEN_SETTINGS,
                          variable: 'MAVEN_SETTINGS_FILE'
                      )
                  ]) {                   
                      sh """
                          mvn clean deploy \
                            -s \${MAVEN_SETTINGS_FILE} \
                            -Danypoint.client.id=${CLIENT_ID} \
                            -Danypoint.client.secret=${CLIENT_SECRET} \
                            -DmuleDeploy \
                            -P${env.ACTIVE_PROFILES} \
                            -Denv=${env.DEPLOY_ENV}
                      """
                  }
              }
          }
      }
  }
  
  stage('Adjust Version') {
      when {
        expression { return env.BRANCH_NAME.startsWith('release/') || env.BRANCH_NAME == 'main' }
      }
      steps {
        sh '''
          echo "Suppression de -SNAPSHOT pour release/main"
          mvn versions:set -DremoveSnapshot
          mvn versions:commit
        '''
      }
    }

    stage('Promote to Prod') {
      when { branch 'main' }
      steps {
        script {
          def anypointCredId = "anypoint-connected-app-prod"
          withCredentials([
            usernamePassword(credentialsId: anypointCredId, usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET')
          ]) {
            configFileProvider([
              configFile(fileId: env.MAVEN_SETTINGS, variable: 'MAVEN_SETTINGS_FILE')
            ]) {
              sh """
                echo "⚠️ ATTENTION: ceci redeploie via Maven. Pas du no-rebuild."
                mvn deploy \
                  -s \${MAVEN_SETTINGS_FILE} \
                  -Danypoint.client.id=\${CLIENT_ID} \
                  -Danypoint.client.secret=\${CLIENT_SECRET} \
                  -DmuleDeploy \
                  -DskipTests \
                  -Denv=prod
              """
            }
          }
        }
      }
    }
    
  }

  post {
    success {
      echo "Pipeline CI/CD MuleSoft terminé avec succès."
    }
    failure {
      echo "Échec du pipeline."
    }
  }
}