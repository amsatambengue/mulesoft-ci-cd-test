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
            //env.MAVEN_SETTINGS = config.mavenSettings
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
      def nexusCredId = 'nexus-releases'
      def anypointCredId = "anypoint-connected-app-${env.DEPLOY_ENV}"

      withCredentials([
        usernamePassword(credentialsId: nexusCredId, usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PWD'),
        usernamePassword(credentialsId: anypointCredId, usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET')
      ]) {
        withMaven(maven: 'maven-3.8.8', publisherStrategy: 'EXPLICIT') {
          
          // Créer settings.xml
          sh '''
            mkdir -p ~/.m2
            cat > ~/.m2/settings.xml <<'XMLEOF'
<settings>
  <pluginGroups>
    <pluginGroup>org.mule.tools</pluginGroup>
  </pluginGroups>
  <servers>
    <server>
      <id>nexus-releases</id>
      <username>NEXUS_USER_PLACEHOLDER</username>
      <password>NEXUS_PWD_PLACEHOLDER</password>
    </server>
    <server>
      <id>anypoint-exchange-v3</id>
      <username>~~~Client~~~</username>
      <password>${CLIENT_ID}~?~${CLIENT_SECRET}</password>
    </server>
  </servers>
</settings>
XMLEOF
            echo "✅ settings.xml créé"
            cat ~/.m2/settings.xml
          '''


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