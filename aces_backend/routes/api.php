<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\CardParserController;

Route::post('/parse-card', [CardParserController::class, 'parseText']);