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
        Schema::table("users", function (Blueprint $table) {
            $table->unsignedBigInteger("tenant_id")->nullable()->after("id");
            $table->string("role", 50)->default("user")->after("password");
            $table->boolean("is_active")->default(true)->after("role");
            $table->string("phone", 20)->nullable()->after("email");
            $table
                ->timestamp("last_login_at")
                ->nullable()
                ->after("remember_token");
            $table->integer("login_count")->default(0)->after("last_login_at");

            $table->index("tenant_id");
            $table->index("role");
            $table->index("is_active");
            $table->index(["tenant_id", "email"]);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table("users", function (Blueprint $table) {
            $table->dropIndex(["tenant_id", "email"]);
            $table->dropIndex(["is_active"]);
            $table->dropIndex(["role"]);
            $table->dropIndex(["tenant_id"]);

            $table->dropColumn([
                "tenant_id",
                "role",
                "is_active",
                "phone",
                "last_login_at",
                "login_count",
            ]);
        });
    }
};
