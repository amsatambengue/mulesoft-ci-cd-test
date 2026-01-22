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

    /* ======================
       Version guards
       ====================== */

    stage('Validate Develop Version (develop = SNAPSHOT)') {
      when { branch 'develop' }
      steps {
        script {
          def v = sh(script: "mvn -q -DforceStdout help:evaluate -Dexpression=project.version", returnStdout: true).trim()
          echo "📦 Version: ${v}"
          if (!v.contains("SNAPSHOT")) {
            error "❌ develop doit rester en SNAPSHOT (ex: 1.0.1-SNAPSHOT). Reçu: ${v}"
          }
        }
      }
    }

    stage('Set Release Version (from branch)') {
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

    stage('Validate Version (release/* = x.y.z)') {
      when { expression { return env.BRANCH_NAME.startsWith('release/') } }
      steps {
        script {
          def rel = env.BRANCH_NAME.replace('release/', '').trim()
          def v = sh(script: "mvn -q -DforceStdout help:evaluate -Dexpression=project.version", returnStdout: true).trim()
          echo "📦 Version: ${v} | Branche: ${rel}"

          if (v.contains("SNAPSHOT")) error "❌ SNAPSHOT interdit sur release/* (version=${v})"
          if (v != rel) error "❌ Version POM (${v}) != version de branche (${rel})"
        }
      }
    }

    stage('Validate MAIN Version (main = release, no SNAPSHOT)') {
      when { branch 'main' }
      steps {
        script {
          def v = sh(script: "mvn -q -DforceStdout help:evaluate -Dexpression=project.version", returnStdout: true).trim()
          echo "📦 Version: ${v}"
          if (v.contains("SNAPSHOT")) {
            error "❌ SNAPSHOT interdit sur main. Main doit promouvoir une release déjà publiée."
          }
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
    stage('Promote to TEST or PROD') {
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
