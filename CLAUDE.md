# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a Laravel-based e-commerce platform ("Dujiaoka") designed for digital goods automation.

- **Framework**: Laravel 6.20.26 (PHP 7.4 required)
- **Admin Panel**: Based on `dcat/laravel-admin`
- **Frontend**: Bootstrap-based with multiple template support (`unicorn`, `luna`, `hyper`)
- **Payment Gateways**: Multiple integrations (Alipay, WeChat, PayPal, Stripe, etc.) via dedicated drivers
- **Task Queue**: Uses Redis driver, managed by Supervisor

### Core Directory Structure

- `app/Admin`: Backend administration logic (Controllers, Repositories)
- `app/Http/Controllers`: Frontend user-facing controllers
- `app/Models`: Eloquent ORM models
- `app/Service`: Business logic encapsulation
- `resources/views`: Blade templates (frontend themes in `common`, `luna`, `hyper`, `unicorn`)
- `routes`: `web.php` for frontend, `admin.php` for backend
- `config`: Application configuration

## Build & Run Commands

### Development Setup

- **Install Dependencies**: `composer install`
- **Frontend Assets**: `npm install && npm run dev`
- **Environment Setup**: `cp .env.example .env` then `php artisan key:generate`
- **Database Migration**: `php artisan migrate`
- **Seed Data**: `php artisan db:seed`

### Common Tasks

- **Run Dev Server**: `php artisan serve` (or configure Nginx/Apache)
- **Watch Assets**: `npm run watch`
- **Queue Worker**: `php artisan queue:work`
- **Clear Cache**: `php artisan cache:clear && php artisan config:clear`

### Testing

- **Run All Tests**: `./vendor/bin/phpunit`
- **Run Single Test**: `./vendor/bin/phpunit tests/Feature/ExampleTest.php`

## Code Style & Conventions

- **PHP Version**: Strict 7.4 compatibility (check `composer.json`)
- **Formatting**: PSR-2/PSR-12 standards
- **Type Safety**: PHP 7.4 type hinting where possible
- **Logic Placement**:
  - Thin Controllers: Delegate business logic to `Service` classes
  - Validation: Use FormRequest classes in `app/Http/Requests` (if available) or validation inside controllers
  - Models: Keep scope to database interactions and relationships

## Important Notes

- **Redis Required**: System heavily relies on Redis for caching and queues.
- **Extensions**: Requires `fileinfo`, `redis` PHP extensions.
- **Admin Path**: Default is `/admin`.
- **Legacy Support**: Be mindful of Laravel 6.x constraints (no PHP 8+ features).
