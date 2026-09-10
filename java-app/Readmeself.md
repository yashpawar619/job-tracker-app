### Java Project Structure EXPLAINED
First check java version,docker and docker compose
Install maven if not install
- i used for these because of windows and env path was also not working soused below
-- "E:\apache-maven\bin\mvn wrapper:wrapper -Dmaven=3.9.9" 
-- "mvnw.cmd clean compile"

### For linux
# With Maven installed globally
mvn clean compile — "Delete old build output, then compile from scratch"
mvn test - "Clean, compile, AND run tests"
mvn spring-boot:run
mvn clean package(optional in local) - "Clean, compile, test, AND create the JAR"
# Or with the wrapper (no global install needed)
./mvnw clean compile
./mvnw test
./mvnw spring-boot:run

## pom.xml
package.json (Node) or requirements.txt (Python) but way more powerful. It defines:
What Java version to use
All dependencies (Spring Boot, PostgreSQL driver, etc.)
How to build, test, and package
Plugins (like Spring Boot's plugin that makes the JAR runnable)

### Local Testing
- Setup docker compose up to test