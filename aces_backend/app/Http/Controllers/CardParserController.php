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
        $apiKey = env('GEMINI_API_KEY');

        // 1. The Bulletproof System Prompt (Cleaned up the copy-paste artifact)
        $prompt = "You are an expert data extraction API. Extract the following business card text into a strict JSON object. 
        Use EXACTLY these keys: Name, Designation, Organisation, Mobile, Telephone, Email, FAX, Address, Links. 
        If a field is missing, make its value null. Fix obvious OCR typos. 
        IMPORTANT: Return ONLY the raw JSON string. Do not use markdown formatting, do not wrap it in\n" . $rawText;

        // 3. Call the Gemini API
        $response = Http::withoutVerifying()->withHeaders([
            'Content-Type' => 'application/json',
        ])->post('https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=' . $apiKey, [
            'contents' => [
                [
                    'parts' => [
                        ['text' => $prompt]
                    ]
                ]
            ],
            'generationConfig' => [
                // This is a Gemini 1.5 feature that guarantees the output is purely JSON
                'response_mime_type' => 'application/json',
            ]
        ]);

        // 4. Handle the Response
        if ($response->successful()) {
            $geminiData = $response->json();
            
            // Extract the actual JSON string from Gemini's response structure
            $extractedJsonString = $geminiData['candidates'][0]['content']['parts'][0]['text'] ?? '{}';
            
            // Decode it into a PHP array so we can send it cleanly back to Flutter
            $parsedCardData = json_decode($extractedJsonString, true);

            return response()->json([
                'status' => 'success',
                'data' => $parsedCardData
            ]);
        }

        // If Gemini fails, return an error
        return response()->json([
            'status' => 'error',
            'message' => 'Failed to process card with AI.',
            'details' => $response->json()
        ], 500);
    }
}