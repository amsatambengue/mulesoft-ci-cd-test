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
                    sizingProfile: 'dev-sizing',
                    mavenSettings: 'maven-settings-dev'
                ],
                'release': [
                    deployEnv: 'test',
                    sizingProfile: 'test-sizing',
                    mavenSettings: 'maven-settings-test'
                ],
                'main': [
                    deployEnv: 'production',
                    sizingProfile: 'prod-sizing',
                    mavenSettings: 'maven-settings-prod'
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

stage('MUnit Tests & Coverage') {
    steps {
        script {
            echo "🔍 Variables d'environnement:"
            sh 'env | grep -i maven || true'
            sh 'java -version'
            sh 'mvn -version'
            
            echo "🧹 Nettoyage des anciens builds MUnit"
            sh 'rm -rf target/munitworkingdir-* || true'
            
            echo "🧪 Lancement des tests MUnit"
            sh """
                mvn clean verify \
                    -s ${MAVEN_SETTINGS_FILE} \
                    -Denv=${env.DEPLOY_ENV} \
                    -DargLine="-Xmx2048m -XX:MaxMetaspaceSize=512m" \
                    -X \
                    -e
            """
        }
    }
    
    post {
        failure {
            sh '''
                echo "=== Logs MUnit ==="
                find target -name "*.log" -type f -exec echo "File: {}" \\; -exec cat {} \\; || true
                
                echo "=== Contenu du répertoire target ==="
                ls -laR target/ || true
            '''
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
      when {
        branch 'main'
      }
      steps {
        echo "Promotion vers CloudHub-Prod depuis artefact Nexus validé"
           sh """
		      mvn deploy \
		        -s ${MAVEN_SETTINGS_FILE} \
		        -Danypoint.client.id=${CLIENT_ID} \
		        -Danypoint.client.secret=${CLIENT_SECRET} \
		        -DmuleDeploy \
		        -DskipTests \
		        -Denv=prod
		    """
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