const cdk = require('aws-cdk-lib');
const lambda = require('aws-cdk-lib/aws-lambda');

class LayaLambdaStack extends cdk.Stack {
  constructor(scope, id, props = {}) {
    super(scope, id, props);

    const memorySize = props.memorySize || 5120;

    const fn = new lambda.DockerImageFunction(this, 'LayaFn', {
      code: lambda.DockerImageCode.fromImageAsset('../docker'),
      memorySize,
      timeout: cdk.Duration.minutes(5),
      architecture: lambda.Architecture.X86_64,
      description: `Laya System One engine (memory=${memorySize} MB)`,
      // --context models=english limita o preload na EXECUÇÃO (sem rebuild da imagem)
      environment: props.lambdaEnv || {},
    });

    const url = fn.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE, // estudo; em produção trocar por IAM/auth
    });

    new cdk.CfnOutput(this, 'LayaUrl', { value: url.url });
    new cdk.CfnOutput(this, 'MemoryMB', { value: String(memorySize) });
  }
}

module.exports = { LayaLambdaStack };
