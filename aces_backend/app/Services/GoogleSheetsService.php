<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;

class GoogleSheetsService
{
    private string $spreadsheetId;
    private string $sheetName = 'Sheet1';
    private array  $credentials;

public function __construct()
{
    $this->spreadsheetId = config('services.google_sheets.spreadsheet_id');

    $path = storage_path('app/google-service-account.json');
    
    if (!file_exists($path)) {
        throw new \Exception('Google service account file not found at: ' . $path);
    }

    $json = file_get_contents($path);
    $decoded = json_decode($json, true);

    if ($decoded === null) {
        throw new \Exception('Invalid JSON in service account file. Error: ' . json_last_error_msg());
    }

    $this->credentials = $decoded;
}
    // ── JWT Auth ──────────────────────────────────────────────────────────────

    private function getAccessToken(): string
    {
        return Cache::remember('google_sheets_token', 3500, function () {
            $now    = time();
            $expiry = $now + 3600;

            $header  = $this->base64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $payload = $this->base64url(json_encode([
                'iss'   => $this->credentials['client_email'],
                'scope' => 'https://www.googleapis.com/auth/spreadsheets',
                'aud'   => 'https://oauth2.googleapis.com/token',
                'iat'   => $now,
                'exp'   => $expiry,
            ]));

            $signingInput = "{$header}.{$payload}";

            // Sign with the private key from the JSON file
            $privateKey = $this->credentials['private_key'];
            openssl_sign($signingInput, $signature, $privateKey, 'SHA256');
            $jwt = "{$signingInput}." . $this->base64url($signature);

            $response = Http::withoutVerifying()->asForm()->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion'  => $jwt,
            ]);

            if (!$response->successful()) {
                throw new \Exception('Google auth failed: ' . $response->body());
            }

            return $response->json('access_token');
        });
    }

    private function base64url(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private function sheetsRequest(): \Illuminate\Http\Client\PendingRequest
    {
        return Http::withoutVerifying()
            ->withToken($this->getAccessToken())
            ->baseUrl('https://sheets.googleapis.com/v4/spreadsheets')
            ->timeout(30);
    }

    // ── Sheet Operations ──────────────────────────────────────────────────────

    /**
     * Get all rows from the sheet (returns array of arrays).
     */
    public function getUsedRows(): array
    {
        $response = $this->sheetsRequest()->get(
            "/{$this->spreadsheetId}/values/{$this->sheetName}"
        );

        if (!$response->successful()) {
            throw new \Exception('Failed to read sheet: ' . $response->body());
        }

        return $response->json('values') ?? [];
    }

    /**
     * Append a new row at the end of existing data.
     */
    public function appendRow(array $rowData): void
    {
        $response = $this->sheetsRequest()->post(
            "/{$this->spreadsheetId}/values/{$this->sheetName}!A1:J1:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS",
            ['values' => [$rowData]]
        );

        if (!$response->successful()) {
            throw new \Exception('Failed to append row: ' . $response->body());
        }
    }

    /**
     * Update a specific row by row number (1-indexed, row 1 = header).
     */
    public function updateRow(int $rowNumber, array $rowData): void
    {
        $range = "{$this->sheetName}!A{$rowNumber}:J{$rowNumber}";

        $response = $this->sheetsRequest()->put(
            "/{$this->spreadsheetId}/values/{$range}?valueInputOption=USER_ENTERED",
            ['values' => [$rowData]]
        );

        if (!$response->successful()) {
            throw new \Exception('Failed to update row: ' . $response->body());
        }
    }

    /**
     * Find existing contact by Name, Mobile, or Email.
     * Returns ['found' => false] or ['found' => true, 'row_number' => int, 'data' => array]
     */
    public function findExistingContact(string $name, string $mobile, string $email): array
    {
        $rows = $this->getUsedRows();

        foreach ($rows as $index => $row) {
            if ($index === 0) continue; // skip header

            // Pad row in case some trailing cells are empty
            $row = array_pad($row, 10, '');

            // Columns: SL, Name, Designation, Organisation, Mobile, Telephone, Email, FAX, Address, Links
            $rowName   = trim($row[1]);
            $rowMobile = trim($row[4]);
            $rowEmail  = trim($row[6]);

            $nameMatch   = strcasecmp($rowName, trim($name)) === 0;
            $mobileMatch = !empty($mobile) && !empty($rowMobile) && $rowMobile === trim($mobile);
            $emailMatch  = !empty($email)  && !empty($rowEmail)  && strcasecmp($rowEmail, trim($email)) === 0;

            if ($nameMatch || $mobileMatch || $emailMatch) {
                return [
                    'found'      => true,
                    'row_number' => $index + 1, // 1-indexed
                    'data'       => $row,
                ];
            }
        }

        return ['found' => false];
    }
}