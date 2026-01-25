pipeline {
  agent any

  tools {
    maven 'maven-3.8.8'
    jdk 'jdk-17'
  }

  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Set Environment') {
      steps {
        script {
          echo "Branche détectée : ${env.BRANCH_NAME}"

          def envConfig = [
            'develop': [deployEnv: 'development', sizingProfile: 'dev-sizing'],
            'release': [deployEnv: 'test',        sizingProfile: 'test-sizing'],
            'main'   : [deployEnv: 'production',  sizingProfile: 'prod-sizing']
          ]

          def configKey = ''
          if (env.BRANCH_NAME == 'develop') {
            configKey = 'develop'
          } else if (env.BRANCH_NAME.startsWith('release/')) {
            configKey = 'release'
          } else if (env.BRANCH_NAME == 'main') {
            configKey = 'main'
          } else {
            error "❌ Branche [${env.BRANCH_NAME}] non gérée pour CI/CD"
          }

          def config = envConfig[configKey]
          env.DEPLOY_ENV      = config.deployEnv
          env.SIZING_PROFILE  = config.sizingProfile
          env.MAVEN_SETTINGS  = 'maven-settings-file'
          env.ACTIVE_PROFILES = "ci,${config.sizingProfile}"

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

    stage('Check & Set Release Version') {
      when { expression { return env.BRANCH_NAME.startsWith('release/') } }
      steps {
        script {
          def rel = env.BRANCH_NAME.replace('release/', '').trim()
          if (!rel.matches('\\d+\\.\\d+\\.\\d+')) {
            error "❌ Branche release invalide: ${env.BRANCH_NAME} (attendu release/x.y.z)"
          }
          sh """
            echo "📌 Setting Maven version to ${rel}"
            mvn -q versions:set -DnewVersion=${rel}
            mvn -q versions:commit
          """
        }
      }
    }
    
    /* ======================
       Version guards - Validation
       ====================== */

	stage('Validate Version Policy') {
	  steps {
	    script {
	      def branch = env.BRANCH_NAME ?: ''
	      def v = sh(script: "mvn -q -DforceStdout help:evaluate -Dexpression=project.version", returnStdout: true).trim()
	      echo "📦 Validate Version | Branch=${branch} | Version=${v}"
	
	      if (branch == 'develop') {
	        if (!v.contains('SNAPSHOT')) {
	          error "❌ develop doit rester en SNAPSHOT (version=${v})"
	        }
	        return
	      }
	
	      if (branch.startsWith('release/')) {
	        def rel = branch.replace('release/', '').trim()
	        if (!rel.matches('\\d+\\.\\d+\\.\\d+')) {
	          error "❌ Branche release invalide: ${branch} (attendu release/x.y.z)"
	        }
	        if (v.contains('SNAPSHOT')) {
	          error "❌ SNAPSHOT interdit sur release/* (version=${v})"
	        }
	        if (v != rel) {
	          error "❌ Version POM (${v}) != version de branche (${rel})"
	        }
	        return
	      }
	
	      if (branch == 'main') {
	        if (v.contains('SNAPSHOT')) {
	          error "❌ SNAPSHOT interdit sur main (version=${v})"
	        }
	        return
	      }
	
	      // autres branches (feature/* etc.) : on ne bloque pas (ou tu peux choisir de bloquer)
	      echo "ℹ️ Branche non gouvernée par policy (pas de blocage): ${branch}"
	    }
	  }
	}



    /* ======================
       DEVELOP : rebuild + deploy DEV
       ====================== */
    stage('(Re)-Build & Deploy to DEVELOPMENT') {
      when { branch 'develop' }
      steps {
        script {
          def anypointCredId = "anypoint-connected-app-development"

          withCredentials([
            usernamePassword(credentialsId: anypointCredId, usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET')
          ]) {
            configFileProvider([
              configFile(fileId: env.MAVEN_SETTINGS, variable: 'MAVEN_SETTINGS_FILE')
            ]) {
              sh """
                mvn clean deploy \
                  -s \${MAVEN_SETTINGS_FILE} \
                  -Danypoint.client.id=\${CLIENT_ID} \
                  -Danypoint.client.secret=\${CLIENT_SECRET} \
                  -DmuleDeploy \
                  -P${env.ACTIVE_PROFILES} \
                  -Denv=development
              """
            }
          }
        }
      }
    }

    /* ======================
       RELEASE/* : Publish to Exchange (release only)
       ====================== */
    stage('Publish Release to Exchange') {
      when { expression { return env.BRANCH_NAME.startsWith('release/') } }
      steps {
        script {
          def anypointCredId = "anypoint-connected-app-test"

          withCredentials([
            usernamePassword(credentialsId: anypointCredId, usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET')
          ]) {
            configFileProvider([
              configFile(fileId: env.MAVEN_SETTINGS, variable: 'MAVEN_SETTINGS_FILE')
            ]) {
              sh """
                mvn clean deploy \
                  -s \${MAVEN_SETTINGS_FILE} \
                  -Danypoint.client.id=\${CLIENT_ID} \
                  -Danypoint.client.secret=\${CLIENT_SECRET} \
                  -Pci,${env.SIZING_PROFILE}
              """
            }
          }
        }
      }
    }

    /* ======================
       RELEASE/* : promote TEST
       MAIN      : promote PROD
       ====================== */
    stage('Promote Release to TEST or PROD') {
      when { expression { return env.BRANCH_NAME.startsWith('release/') || env.BRANCH_NAME == 'main' } }
      steps {
        script {
          def targetEnv = (env.BRANCH_NAME.startsWith('release/')) ? 'test' : 'production'
          def anypointCredId = "anypoint-connected-app-${targetEnv}"

          withCredentials([
            usernamePassword(credentialsId: anypointCredId, usernameVariable: 'CLIENT_ID', passwordVariable: 'CLIENT_SECRET')
          ]) {
            configFileProvider([
              configFile(fileId: env.MAVEN_SETTINGS, variable: 'MAVEN_SETTINGS_FILE')
            ]) {
              timeout(time: 45, unit: 'MINUTES') {
                sh """
                  mvn mule:deploy \
                    -s \${MAVEN_SETTINGS_FILE} \
                    -Danypoint.client.id=\${CLIENT_ID} \
                    -Danypoint.client.secret=\${CLIENT_SECRET} \
                    -Denv=${targetEnv}
                """
              }
            }
          }
        }
      }
    }

  }

  post {
    success { echo "✅ Pipeline CI/CD MuleSoft terminé avec succès." }
    failure { echo "❌ Échec du pipeline." }
  }
}
