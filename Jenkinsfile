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

          if (env.BRANCH_NAME == 'develop') {
            env.MULE_ENV = 'dev'
          } else if (env.BRANCH_NAME.startsWith('release/')) {
            env.MULE_ENV = 'test'
          } else if (env.BRANCH_NAME == 'main') {
            env.MULE_ENV = 'prod'
          } else {
            error "❌ Branche non gérée pour déploiement CI/CD : ${env.BRANCH_NAME}"
          }

          env.ACTIVE_PROFILES = "ci,${env.MULE_ENV}"
          echo "✅ Environnement MULE_ENV : ${env.MULE_ENV}"
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
	      def anypointCredId = "anypoint_credential_${env.MULE_ENV}"
	      
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
	      def anypointCredId = "anypoint-connected-app-${env.MULE_ENV}"
	
	      withCredentials([
	        usernamePassword(credentialsId: nexusCredId, usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PWD'),
	        usernamePassword(credentialsId: anypointCredId, usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET')
	      ]) {
	        withMaven(maven: 'maven-3.8.8', publisherStrategy: 'EXPLICIT') {
	          // Créer settings.xml de manière sécurisée avec des variables shell
	          sh '''
	          mkdir -p ~/.m2
	          cat > ~/.m2/settings.xml <<EOF
	<settings>
	  <servers>
	    <server>
	      <id>nexus-releases</id>
	      <username>${NEXUS_USER}</username>
	      <password>${NEXUS_PWD}</password>
	    </server>
	    <server>
	      <id>anypoint-exchange-v3</id>
	      <username>${CLIENT_ID}</username>
	      <password>${CLIENT_SECRET}</password>
	    </server>
	  </servers>
	</settings>
	EOF
	          
	          echo "✅ settings.xml créé"
	          echo "CLIENT_ID: ${CLIENT_ID}"
	          echo "Environnement: ''' + env.MULE_ENV + '''"
	          echo "Profils actifs: ''' + env.ACTIVE_PROFILES + '''"
	          
	          # Vérifier que le fichier est valide
	          cat ~/.m2/settings.xml
	          
	          mvn clean deploy \
	            -P''' + env.ACTIVE_PROFILES + ''' \
	            -Dmule.env=''' + env.MULE_ENV + ''' \
	            -Danypoint.client.id=${CLIENT_ID} \
	            -Danypoint.client.secret=${CLIENT_SECRET} \
	            -DmuleDeploy \
	            -DskipTests
	          '''
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
        sh "mvn deploy -P${env.ACTIVE_PROFILES} -Dmule.env=${env.MULE_ENV} -DskipTests"
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