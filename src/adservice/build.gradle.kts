plugins {
  id ("org.sonarqube") version "5.0.0.4638"
}

sonar {
  properties {
    property("sonar.projectKey", "achtix-homelab_ad-service_a48206a5-5f3d-458e-ac1b-bcba60f1fd64")
    property("sonar.projectName", "ad service")
    property("sonar.qualitygate.wait", true)
  }
}
