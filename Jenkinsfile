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

                    // settings.xml avec le bon format pour Enterprise repos
                    sh """
                        mkdir -p ~/.m2
                        cat > ~/.m2/settings.xml <<'XMLEOF'
<?xml version="1.0"?>
<settings>
  <pluginGroups>
    <pluginGroup>org.mule.tools</pluginGroup>
  </pluginGroups>
  
  <servers>
    <!-- Pour Anypoint Exchange -->
    <server>
      <id>anypoint-exchange-v3</id>
      <username>~~~Client~~~</username>
      <password>CLIENT_ID_PLACEHOLDER~?~CLIENT_SECRET_PLACEHOLDER</password>
    </server>
    
    <!-- Pour MuleSoft Enterprise Repository -->
    <server>
      <id>mule-enterprise</id>
      <username>~~~Client~~~</username>
      <password>CLIENT_ID_PLACEHOLDER~?~CLIENT_SECRET_PLACEHOLDER</password>
    </server>
    
    <!-- Pour MuleSoft Releases -->
    <server>
      <id>mulesoft-releases</id>
      <username>~~~Client~~~</username>
      <password>CLIENT_ID_PLACEHOLDER~?~CLIENT_SECRET_PLACEHOLDER</password>
    </server>
  </servers>

  <profiles>
    <profile>
      <id>mule-repos</id>
      <activation>
        <activeByDefault>true</activeByDefault>
      </activation>
      <repositories>
        <repository>
          <id>mule-enterprise</id>
          <name>Mule Enterprise Repository</name>
          <url>https://repository.mulesoft.org/nexus-ee/content/repositories/releases-ee/</url>
          <layout>default</layout>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>
        <repository>
          <id>mulesoft-releases</id>
          <name>Mulesoft Releases Repository</name>
          <url>https://repository.mulesoft.org/releases/</url>
          <layout>default</layout>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>false</enabled>
          </snapshots>
        </repository>
        <repository>
          <id>anypoint-exchange-v3</id>
          <name>Anypoint Exchange V3</name>
          <url>https://maven.anypoint.mulesoft.com/api/v3/maven</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>
      </repositories>
      
      <pluginRepositories>
        <pluginRepository>
          <id>mule-enterprise</id>
          <name>Mule Enterprise Repository</name>
          <url>https://repository.mulesoft.org/nexus-ee/content/repositories/releases-ee/</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </pluginRepository>
        <pluginRepository>
          <id>mulesoft-releases</id>
          <name>Mulesoft Releases Repository</name>
          <url>https://repository.mulesoft.org/releases/</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>false</enabled>
          </snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
</settings>
XMLEOF
                        
                        # Remplacer les placeholders avec les vraies valeurs
                        sed -i "s|CLIENT_ID_PLACEHOLDER|${CLIENT_ID}|g" ~/.m2/settings.xml
                        sed -i "s|CLIENT_SECRET_PLACEHOLDER|${CLIENT_SECRET}|g" ~/.m2/settings.xml
                    """

                    if (env.DEPLOY_ENV == 'dev') {
                        echo "🌍 Déploiement DEV avec tests (env=${env.DEPLOY_ENV})"

                        sh """
                            mvn clean deploy \
                                -U \
                                -Denv=${DEPLOY_ENV} \
                                -DmuleDeploy \
                                -Danypoint.client.id=${CLIENT_ID} \
                                -Danypoint.client.secret=${CLIENT_SECRET}
                        """
                    } else {
                        echo "🌍 Déploiement ${env.DEPLOY_ENV} en mode CI (-Pci, sans tests)"

                        sh """
                            mvn clean deploy \
                                -Denv=${DEPLOY_ENV} \
                                -Pci \
                                -DmuleDeploy \
                                -Danypoint.client.id=${CLIENT_ID} \
                                -Danypoint.client.secret=${CLIENT_SECRET}
                        """
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