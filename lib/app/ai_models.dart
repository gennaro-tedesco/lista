const googleModel = 'gemini-3.1-flash-lite';
const qwenModel = 'qwen/qwen3.8-omni-flash';
const xiaomiModel = 'xiaomi/mimo-v2.6-flash';

class AiModelPricing {
  const AiModelPricing({required this.inputPer1m, required this.outputPer1m});

  final double inputPer1m;
  final double outputPer1m;
}
