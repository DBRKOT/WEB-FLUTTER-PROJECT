const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

const apiDebugDelayMs = int.fromEnvironment('API_DELAY', defaultValue: 0);
const apiDebugFailStatus = int.fromEnvironment('API_FAIL', defaultValue: 0);
