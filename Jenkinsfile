pipeline {
  agent any

  tools {
    maven 'maven-3.8.8'
    jdk 'jdk-17'
  }

  environment {
    ACTIVE_PROFILES = 'ci'
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
            echo "📌 Branche détectée : ${env.BRANCH_NAME}"
            
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
            env.DEPLOY_ENV = config.deployEnv
            env.SIZING_PROFILE = config.sizingProfile
            env.MAVEN_SETTINGS = config.mavenSettings
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

    stage('Test Anypoint Auth') {
      steps {
        script {
          def anypointCredId = "anypoint-connected-app-${env.DEPLOY_ENV}"
          
          withCredentials([
            usernamePassword(credentialsId: anypointCredId, usernameVariable: 'TEST_CLIENT_ID', passwordVariable: 'TEST_CLIENT_SECRET')
          ]) {
            sh '''
            echo "🔐 Test d'authentification Anypoint..."
            
            RESPONSE=$(curl -s -w "\\n%{http_code}" -X POST \
              https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
              -H "Content-Type: application/json" \
              -d "{
                \\"grant_type\\": \\"client_credentials\\",
                \\"client_id\\": \\"$TEST_CLIENT_ID\\",
                \\"client_secret\\": \\"$TEST_CLIENT_SECRET\\"
              }")
            
            HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
            BODY=$(echo "$RESPONSE" | head -n-1)
            
            echo "HTTP Status: $HTTP_CODE"
            
            if [ "$HTTP_CODE" = "200" ]; then
              echo "✅ Authentification réussie!"
              echo "$BODY" | grep -o '"access_token":"[^"]*"' | head -c 80
            else
              echo "❌ Échec d'authentification!"
              echo "$BODY"
              exit 1
            fi
            '''
          }
        }
      }
    }

	stage('Build & Deploy') {
	    steps {
	        script {
	            // Définition des credentials
	            def nexusCredId = 'nexus-releases'
	            def anypointCredId = "anypoint-connected-app-${env.DEPLOY_ENV}"
	            
	            echo """
	            ════════════════════════════════════════════════════════════
	            🚀 Démarrage du Build & Deploy
	            ════════════════════════════════════════════════════════════
	            🔑 Nexus Credential      : ${nexusCredId}
	            🔑 Anypoint Credential   : ${anypointCredId}
	            📋 Maven Settings        : ${env.MAVEN_SETTINGS}
	            🌍 Environnement cible   : ${env.DEPLOY_ENV}
	            🔧 Profils Maven         : ${env.ACTIVE_PROFILES}
	            ════════════════════════════════════════════════════════════
	            """
	            
	            // Validation des variables requises
	            if (!env.DEPLOY_ENV || !env.MAVEN_SETTINGS || !env.ACTIVE_PROFILES) {
	                error "❌ Variables d'environnement manquantes. Assurez-vous que le stage 'Set Environment' a été exécuté."
	            }
	            
	            try {
	                withCredentials([
	                    usernamePassword(
	                        credentialsId: nexusCredId, 
	                        usernameVariable: 'NEXUS_USER', 
	                        passwordVariable: 'NEXUS_PWD'
	                    ),
	                    usernamePassword(
	                        credentialsId: anypointCredId, 
	                        usernameVariable: 'CLIENT_ID', 
	                        passwordVariable: 'CLIENT_SECRET'
	                    )
	                ]) {
	                    // Utiliser env.MAVEN_SETTINGS au lieu de hardcoder 'maven-settings-dev'
	                    configFileProvider([
	                        configFile(
	                            fileId: env.MAVEN_SETTINGS,  // ✅ CORRECTION: Utiliser la variable d'env
	                            variable: 'MAVEN_SETTINGS_FILE'
	                        )
	                    ]) {
	                        // Afficher preview des credentials (sécurisé)
	                        sh """
	                            echo "🔐 Client ID (preview): \$(echo ${CLIENT_ID} | cut -c1-8)..."
	                            echo "📦 Démarrage de la commande Maven..."
	                        """
	                        
	                        // Commande Maven
	                        sh """
	                            mvn clean deploy \
	                              -s \${MAVEN_SETTINGS_FILE} \
	                              -Danypoint.client.id=${CLIENT_ID} \
	                              -Danypoint.client.secret=${CLIENT_SECRET} \
	                              -DmuleDeploy \
	                              -P${env.ACTIVE_PROFILES} \
	                              -Denv=${env.DEPLOY_ENV}
	                        """
	                        
	                        echo "✅ Déploiement vers ${env.DEPLOY_ENV} terminé avec succès!"
	                    }
	                }
	            } catch (Exception e) {
	                echo """
	                ════════════════════════════════════════════════════════════
	                ❌ ERREUR LORS DU DÉPLOIEMENT
	                ════════════════════════════════════════════════════════════
	                Environnement : ${env.DEPLOY_ENV}
	                Erreur        : ${e.message}
	                ════════════════════════════════════════════════════════════
	                """
	                throw e
	            }
	        }
	    }
	}

    stage('Promote to Prod') {
      when {
        branch 'main'
      }
      steps {
        echo "Promotion vers CloudHub-Prod depuis artefact Nexus validé"
        sh "mvn deploy -P${env.ACTIVE_PROFILES} -Denv=${env.DEPLOY_ENV} -DskipTests"
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