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
	      
	      def deployEnv = ''

          if (env.BRANCH_NAME == 'develop') {
            	deployEnv = 'development'
          } else if (env.BRANCH_NAME.startsWith('release/')) {
            	deployEnv = 'test'
          } else if (env.BRANCH_NAME == 'main') {
            	deployEnv = 'production'
          } else {
            	error "❌ Branche ---> [${env.BRANCH_NAME}] non gérée pour déploiement CI/CD"
          }
          
          env.DEPLOY_ENV = deployEnv
          env.ACTIVE_PROFILES = "ci,${env.DEPLOY_ENV}"
          
          echo "✅ Environnement DEPLOY_ENV : ${env.DEPLOY_ENV}"
          echo "✅ Profils Maven actifs : ${env.ACTIVE_PROFILES}"
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
      def nexusCredId = 'nexus-releases'
      def anypointCredId = "anypoint-connected-app-${env.DEPLOY_ENV}"
      def mavenSettingsId = 'maven-settings-dev'

		// Choix dynamique du settings.xml selon l'env (tu crées 3 fichiers dans Jenkins)
	      if (env.BRANCH_NAME == 'develop') {
		  mavenSettingsId = 'maven-settings-dev'
		} else if (env.DEPLOY_ENV == 'test') {
		  mavenSettingsId = 'maven-settings-test'
		} else if (env.DEPLOY_ENV == 'production') {
		  mavenSettingsId = 'maven-settings-prod'
		}

      echo "✅ Applied Maven Settings:  ${mavenSettingsId}"


      withCredentials([
        usernamePassword(credentialsId: nexusCredId, usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PWD'),
        usernamePassword(credentialsId: anypointCredId, usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET')
      ]) {
        withMaven(
        maven: 'maven-3.8.8',
        mavenSettingsConfig: mavenSettingsId,  // Ici l'injection magique ! 
        publisherStrategy: 'EXPLICIT'
        ) {
             
          // Logs de debug
          sh """
            echo "CLIENT_ID: ${CLIENT_ID}"
            echo "Environnement: ${env.DEPLOY_ENV}"
            echo "Profils actifs: ${env.ACTIVE_PROFILES}"
          """

          // Déploiement Maven
          sh """
            mvn clean deploy \
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