<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class CardParserController extends Controller
{
    public function parseText(Request $request)
    {
        $request->validate([
            'raw_text' => 'required|string',
        ]);

        $rawText = $request->input('raw_text');
        $apiKey  = config('services.gemini.key'); // use config(), not env()

        $prompt = "You are an expert data extraction API. Extract the following business card text into a strict JSON object.
Use EXACTLY these keys: Name, Designation, Organisation, Mobile, Telephone, Email, FAX, Address, Links.
If a field is missing, make its value null. Fix obvious OCR typos.
IMPORTANT: Return ONLY the raw JSON string. Do not use markdown formatting, do not wrap in backticks.

Business card text:
" . $rawText;

        $response = Http::withoutVerifying()
            ->timeout(30)
            ->withHeaders(['Content-Type' => 'application/json'])
            ->post('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=' . $apiKey, [
                'contents' => [
                    ['parts' => [['text' => $prompt]]]
                ],
                'generationConfig' => [
                    'temperature'     => 0.1,
                    'maxOutputTokens' => 512,
                ],
            ]);

        if ($response->successful()) {
            $geminiData        = $response->json();
            $extractedJson     = $geminiData['candidates'][0]['content']['parts'][0]['text'] ?? '{}';

            // Strip any accidental markdown fences
            $extractedJson = trim(preg_replace('/```json|```/', '', $extractedJson));

            $parsedCardData = json_decode($extractedJson, true);

            return response()->json([
                'status' => 'success',
                'data'   => $parsedCardData,
            ]);
        }

        return response()->json([
            'status'  => 'error',
            'message' => 'Failed to process card with AI.',
            'details' => $response->json(),
        ], 500);
    }
}