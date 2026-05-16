<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\GoogleSheetsService;

class SyncController extends Controller
{
    public function __construct(private GoogleSheetsService $sheets) {}

    /**
     * POST /api/sync-contact
     */
    public function syncContact(Request $request)
    {
        $request->validate(['name' => 'required|string']);

        $name         = trim($request->input('name', ''));
        $designation  = trim($request->input('designation', ''));
        $organisation = trim($request->input('organisation', ''));
        $mobile       = trim($request->input('mobile', ''));
        $telephone    = trim($request->input('telephone', ''));
        $email        = trim($request->input('email', ''));
        $fax          = trim($request->input('fax', ''));
        $address      = trim($request->input('address', ''));
        $links        = trim($request->input('links', ''));

        try {
            $existing = $this->sheets->findExistingContact($name, $mobile, $email);

            // ── Rule 3: Brand new ─────────────────────────────────────────
            if (!$existing['found']) {
                $rows   = $this->sheets->getUsedRows();
                $nextSl = count($rows);

                $this->sheets->appendRow([
                    $nextSl, $name, $designation, $organisation,
                    $mobile, $telephone, $email, $fax, $address, $links,
                ]);

                return response()->json(['status' => 'saved', 'message' => 'New contact added to Google Sheets.']);
            }

            $existingData        = array_pad($existing['data'], 10, '');
            $existingDesignation = trim($existingData[2]);
            $existingOrg         = trim($existingData[3]);

            $designationChanged = !empty($designation) && strcasecmp($existingDesignation, $designation) !== 0;
            $orgChanged         = !empty($organisation) && strcasecmp($existingOrg, $organisation) !== 0;

            // BUG FIX: Build resolved_row by merging incoming + existing.
            // For each field: use the incoming value if it is non-empty,
            // otherwise fall back to whatever was already in the sheet.
            // This prevents a partial rescan from wiping out existing data
            // (e.g. address was on the sheet but not on the new scan).
            $mergedRow = [
                $existingData[0],                                          // SL (unchanged)
                $name,                                                     // Name (always from incoming)
                $designation  ?: trim($existingData[2]),                   // Designation
                $organisation ?: trim($existingData[3]),                   // Organisation
                $mobile       ?: trim($existingData[4]),                   // Mobile
                $telephone    ?: trim($existingData[5]),                   // Telephone
                $email        ?: trim($existingData[6]),                   // Email
                $fax          ?: trim($existingData[7]),                   // FAX
                $address      ?: trim($existingData[8]),                   // Address
                $links        ?: trim($existingData[9]),                   // Links
            ];

            // ── Rule 1: Designation changed ───────────────────────────────
            if ($designationChanged && !$orgChanged) {
                return response()->json([
                    'status'        => 'conflict',
                    'conflict_type' => 'designation_change',
                    'message'       => "Update {$name}'s designation?",
                    'existing'      => ['designation' => $existingDesignation, 'organisation' => $existingOrg],
                    'incoming'      => ['designation' => $designation,         'organisation' => $organisation],
                    'row_number'    => $existing['row_number'],
                    'resolved_row'  => $mergedRow,
                ]);
            }

            // ── Rule 2: Company changed ───────────────────────────────────
            if ($orgChanged) {
                return response()->json([
                    'status'        => 'conflict',
                    'conflict_type' => 'company_change',
                    'message'       => "Is this the same {$name}, or a new contact?",
                    'existing'      => ['designation' => $existingDesignation, 'organisation' => $existingOrg],
                    'incoming'      => ['designation' => $designation,         'organisation' => $organisation],
                    'row_number'    => $existing['row_number'],
                    'resolved_row'  => $mergedRow,
                ]);
            }

            // ── Exact duplicate ───────────────────────────────────────────
            return response()->json(['status' => 'duplicate', 'message' => "{$name} already exists and is up to date."]);

        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * POST /api/resolve-conflict
     */
    public function resolveConflict(Request $request)
    {
        $request->validate([
            'action'       => 'required|in:update,new',
            'resolved_row' => 'required|array',
        ]);

        try {
            if ($request->input('action') === 'update') {
                $this->sheets->updateRow(
                    $request->input('row_number'),
                    $request->input('resolved_row')
                );
            } else {
                $rows   = $this->sheets->getUsedRows();
                $row    = $request->input('resolved_row');
                $row[0] = count($rows);
                $this->sheets->appendRow($row);
            }

            return response()->json(['status' => 'saved', 'message' => 'Contact saved to Google Sheets.']);

        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }
}