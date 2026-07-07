FROM jenkins/jenkins:lts-jdk21

USER root

COPY docker/jenkins-controller/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY ci/jcasc/jenkins.yaml /usr/share/jenkins/casc_configs/jenkins.yaml

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true"
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc_configs/jenkins.yaml

USER jenkins

RUN git config --global --add safe.directory '*'
