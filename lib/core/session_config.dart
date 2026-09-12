
const sessionIdleSeconds = int.fromEnvironment('SESSION_IDLE', defaultValue: 180);
const sessionWarnSeconds = int.fromEnvironment('SESSION_WARN', defaultValue: 30);
const sessionMaxSeconds = int.fromEnvironment('SESSION_MAX', defaultValue: 900);

Duration get sessionIdleTimeout => Duration(seconds: sessionIdleSeconds);
Duration get sessionWarnBefore => Duration(seconds: sessionWarnSeconds);
Duration get sessionMaxDuration => Duration(seconds: sessionMaxSeconds);
