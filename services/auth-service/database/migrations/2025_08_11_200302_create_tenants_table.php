<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create("tenants", function (Blueprint $table) {
            $table->id();
            $table->string("name");
            $table->string("slug")->unique();
            $table->string("domain")->unique()->nullable();
            $table->string("database")->unique();
            $table
                ->enum("status", [
                    "pending",
                    "active",
                    "suspended",
                    "cancelled",
                ])
                ->default("pending");
            $table->string("plan", 50)->default("basic");
            $table->timestamp("trial_ends_at")->nullable();
            $table->timestamp("subscription_ends_at")->nullable();
            $table->json("settings")->nullable();
            $table->json("metadata")->nullable();
            $table->json("features")->nullable();
            $table->unsignedBigInteger("owner_id")->nullable();
            $table->integer("max_users")->nullable();
            $table->integer("max_storage")->nullable(); // in MB
            $table->timestamps();
            $table->softDeletes();

            $table->index("status");
            $table->index("plan");
            $table->index("slug");
            $table->index("domain");
            $table
                ->foreign("owner_id")
                ->references("id")
                ->on("users")
                ->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists("tenants");
    }
};
