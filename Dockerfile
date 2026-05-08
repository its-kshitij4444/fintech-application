FROM tomcat:9.0-jdk17

RUN rm -rf /usr/local/tomcat/webapps/ROOT
COPY app.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080
ENV JAVA_OPTS=""
CMD ["bash", "-c", "JAVA_OPTS=\"-DDB_URL=$DB_URL -DDB_USER=$DB_USER -DDB_PASSWORD=$DB_PASSWORD\" /usr/local/tomcat/bin/catalina.sh run"]