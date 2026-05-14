<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\CardParserController;
use App\Http\Controllers\SyncController;

Route::post('/parse-card',       [CardParserController::class, 'parseText']);
Route::post('/sync-contact',     [SyncController::class, 'syncContact']);
Route::post('/resolve-conflict', [SyncController::class, 'resolveConflict']);