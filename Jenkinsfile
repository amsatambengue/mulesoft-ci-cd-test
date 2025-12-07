stage('Build & Deploy (CloudHub 2.0)') {
  steps {
    script {
      def anypointCredId = 'anypoint_credential'

      withCredentials([
        usernamePassword(
          credentialsId: anypointCredId,
          usernameVariable: 'CLIENT_ID',
          passwordVariable: 'CLIENT_SECRET'
        )
      ]) {
        withMaven(maven: 'maven-3.8.8', publisherStrategy: 'EXPLICIT') {

          // settings.xml pour anypoint-exchange-v3
          sh """
            mkdir -p ~/.m2

            cat > ~/.m2/settings.xml <<EOF
<settings>
  <servers>
    <server>
      <id>anypoint-exchange-v3</id>
      <username>${CLIENT_ID}</username>
      <password>${CLIENT_SECRET}</password>
    </server>
  </servers>
</settings>
EOF
          """

          if (env.DEPLOY_ENV == 'dev') {
            echo "🌍 Déploiement DEV avec tests (env=${env.DEPLOY_ENV})"

            sh """
              mvn clean deploy \
                -Denv=${DEPLOY_ENV} \
                -DmuleDeploy
            """
          } else {
            echo "🌍 Déploiement ${env.DEPLOY_ENV} en mode CI (-Pci, sans tests)"

            sh """
              mvn clean deploy \
                -Denv=${DEPLOY_ENV} \
                -Pci \
                -DmuleDeploy
            """
          }
        }
      }
    }
  }
}
