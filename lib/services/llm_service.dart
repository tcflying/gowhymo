import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

final Dio dio = Dio();

Future<Response> callLlmApi({
  required String url,
  required String model,
  required List<Map<String, String>> messages,
  required bool needThink,
  CancelToken? cancelToken,
  required bool stream,
  required double temperature,
  List<Map<String, dynamic>>? tools,
  required String token,
}) async {
  final data = {
    'model': model,
    'messages': messages,
    "chat_template_kwargs": {"enable_thinking": needThink},
    'temperature': temperature,
    'stream': stream,
  };

  if (tools != null && tools.isNotEmpty) {
    data['tools'] = tools;
  }

  return await dio.post(
    url,
    options: Options(
      responseType: stream ? ResponseType.stream : ResponseType.json,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      receiveTimeout: const Duration(minutes: 10),
    ),
    cancelToken: cancelToken,
    data: data,
  );
}

Future<String> callLlm({
  required String systemPrompt,
  required String prompt,
  required double temperature,
  bool needThink = false,
  String url = qwenUrl,
  String model = qwenModel,
  CancelToken? cancelToken,
  required String token,
}) async {
  final messages = [
    {'role': 'system', 'content': systemPrompt},
    {'role': 'user', 'content': prompt},
  ];

  try {
    final response = await callLlmApi(
      url: url,
      model: model,
      messages: messages,
      needThink: needThink,
      cancelToken: cancelToken,
      stream: false,
      temperature: temperature,
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception('Request failed with status: ${response.statusCode}');
    }

    final responseData = response.data;
    if (responseData.containsKey('choices') &&
        responseData['choices'].isNotEmpty &&
        responseData['choices'][0].containsKey('message') &&
        responseData['choices'][0]['message'].containsKey('content')) {
      return responseData['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Unexpected response structure from LLM API');
    }
  } catch (error) {
    log("error:$error", name: 'callLlm');
    rethrow;
  }
}

Future<Map<String, dynamic>> callLlmFunction({
  required String systemPrompt,
  required String prompt,
  required List<Map<String, dynamic>> tools,
  required double temperature,
  bool needThink = false,
  String url = qwenUrl,
  String model = qwenModel,
  CancelToken? cancelToken,
  required String token,
}) async {
  final messages = [
    {'role': 'system', 'content': systemPrompt},
    {'role': 'user', 'content': prompt},
  ];

  try {
    final response = await callLlmApi(
      url: url,
      model: model,
      messages: messages,
      needThink: needThink,
      cancelToken: cancelToken,
      stream: false,
      temperature: temperature,
      tools: tools,
      token: token,
    );

    if (response.statusCode != 200) {
      throw Exception('Request failed with status: ${response.statusCode}');
    }

    final responseData = response.data;
    if (responseData.containsKey('choices') &&
        responseData['choices'].isNotEmpty &&
        responseData['choices'][0].containsKey('message')) {
      final message = responseData['choices'][0]['message'];

      if (message.containsKey('tool_calls') &&
          message['tool_calls'].isNotEmpty) {
        final toolCall = message['tool_calls'][0];
        if (toolCall.containsKey('function') &&
            toolCall['function'].containsKey('arguments')) {
          final arguments = toolCall['function']['arguments'] as String;
          return jsonDecode(arguments) as Map<String, dynamic>;
        }
      }

      if (message.containsKey('content')) {
        final content = message['content'] as String;
        try {
          return jsonDecode(content) as Map<String, dynamic>;
        } catch (e) {
          return {'content': content};
        }
      }
    }

    throw Exception('Invalid response format');
  } catch (error) {
    log("error:$error", name: "callLlmFunction");
    rethrow;
  }
}
