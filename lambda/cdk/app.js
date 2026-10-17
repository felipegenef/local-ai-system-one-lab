const cdk = require('aws-cdk-lib');
const { LayaLambdaStack } = require('./stack');

const app = new cdk.App();
new LayaLambdaStack(app, 'LayaLambda', {
  // bench.sh and the memory experiment change this via: cdk deploy --context memory=3072
  memorySize: Number(app.node.tryGetContext('memory')) || 5120,
  // --context models=english,typed-decisions → restrict preload WITHOUT an image rebuild
  lambdaEnv: app.node.tryGetContext('models') ? { LAYA_MODELS: String(app.node.tryGetContext('models')) } : undefined,
});
app.synth();
