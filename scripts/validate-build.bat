@echo off
echo 🚀 Quick Build Validation for Compose Portal Application
echo ================================================================
echo.

echo 🔍 Checking Prerequisites...
echo.

echo Java Version:
java -version 2>&1 | findstr "version"
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Java not found. Please install Java 17+
    exit /b 1
)
echo.

echo Maven Version:
mvn -version 2>&1 | findstr "Apache Maven"
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Maven not found. Please install Maven 3.8+
    exit /b 1
)
echo.

echo Docker Version:
docker --version 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ Docker not found. Some features will be limited.
) else (
    echo ✅ Docker is available
)
echo.

echo 🏗️ Building All Services...
mvn clean package -DskipTests
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Build failed!
    exit /b 1
)
echo.
echo ✅ Build completed successfully!

echo.
echo 📊 Verifying JAR files...
for /r %%i in (target\*.jar) do (
    if not "%%~ni" == "*original*" (
        echo ✅ Found: %%i
    )
)

echo.
echo 🎉 Local validation completed successfully!
echo.
echo 🔗 Next Steps:
echo 1. Check GitHub Actions: https://github.com/TechNaidu/compose-portal-service-applications/actions
echo 2. View workflow runs and build status
echo 3. Test Docker images if Docker is available
echo.
