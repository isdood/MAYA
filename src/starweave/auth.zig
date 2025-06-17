const std = @import("std");
const crypto = std.crypto;
const base64 = std.base64;
const json = std.json;
const Allocator = std.mem.Allocator;
const time = std.time;
const fmt = std.fmt;
const hmac = std.crypto.auth.hmac;
const hmac_sha256 = hmac.sha2.HmacSha256;

/// Supported authentication methods
pub const AuthMethod = enum {
    /// Simple token-based authentication
    token,
    
    /// JSON Web Token (JWT) authentication
    jwt,
    
    /// OAuth 2.0 Bearer token
    oauth2,
    
    /// HMAC-based authentication
    hmac_sha256,
    
    /// API key authentication
    api_key,
};

pub const AuthError = error{
    InvalidToken,
    TokenExpired,
    AuthenticationFailed,
    PermissionDenied,
    InvalidSignature,
    TokenNotYetValid,
    InvalidIssuer,
    InvalidAudience,
    InvalidAlgorithm,
    KeyRequired,
    InvalidKey,
    TokenGenerationFailed,
    RefreshFailed,
    UnsupportedAuthMethod,
};

/// Configuration for token-based authentication
pub const TokenConfig = struct {
    /// The authentication token
    token: []const u8,
    
    /// Token expiration timestamp (0 means no expiry)
    expiry: i64 = 0,
    
    /// Optional refresh token
    refresh_token: ?[]const u8 = null,
    
    /// Optional token type (e.g., "Bearer")
    token_type: ?[]const u8 = null,
};

/// Configuration for JWT authentication
pub const JwtConfig = struct {
    /// The JWT token
    token: []const u8,
    
    /// Optional public key for verification
    public_key: ?[]const u8 = null,
    
    /// Required audience
    audience: ?[]const u8 = null,
    
    /// Required issuer
    issuer: ?[]const u8 = null,
    
    /// Allowed clock skew in seconds
    leeway: u64 = 60,
};

/// Configuration for OAuth2 authentication
pub const OAuth2Config = struct {
    /// OAuth2 access token
    access_token: []const u8,
    
    /// Token type (usually "Bearer")
    token_type: []const u8 = "Bearer",
    
    /// Refresh token (if available)
    refresh_token: ?[]const u8 = null,
    
    /// Token expiration timestamp (0 means no expiry)
    expires_in: i64 = 0,
    
    /// Token scopes
    scope: ?[]const u8 = null,
};

/// Configuration for HMAC authentication
pub const HmacConfig = struct {
    /// API key ID
    key_id: []const u8,
    
    /// Secret key for HMAC
    secret_key: []const u8,
    
    /// Header name for the key ID (default: "X-API-Key")
    key_id_header: []const u8 = "X-API-Key",
    
    /// Header name for the signature (default: "X-API-Signature")
    signature_header: []const u8 = "X-API-Signature",
    
    /// Algorithm to use (default: sha256)
    algorithm: enum { sha256, sha384, sha512 } = .sha256,
};

/// Generic API key configuration
pub const ApiKeyConfig = struct {
    /// The API key
    api_key: []const u8,
    
    /// Header name (default: "X-API-Key")
    header_name: []const u8 = "X-API-Key",
    
    /// Optional prefix (e.g., "Bearer ")
    prefix: ?[]const u8 = null,
};

/// Union of all authentication configurations
pub const AuthConfig = union(AuthMethod) {
    token: TokenConfig,
    jwt: JwtConfig,
    oauth2: OAuth2Config,
    hmac_sha256: HmacConfig,
    api_key: ApiKeyConfig,
};

/// Manages authentication state and token refresh
pub const AuthManager = struct {
    allocator: Allocator,
    config: AuthConfig,
    last_refresh: i64,
    
    /// Initialize a new AuthManager with the given configuration
    pub fn init(allocator: Allocator, config: AuthConfig) AuthManager {
        return .{
            .allocator = allocator,
            .config = config,
            .last_refresh = time.timestamp(),
        };
    }
    
    /// Clean up any allocated resources
    pub fn deinit(self: *AuthManager) void {
        // Clean up any allocated resources based on the auth method
        switch (self.config) {
            .token => |*token| {
                if (token.refresh_token) |rt| self.allocator.free(rt);
                if (token.token_type) |tt| self.allocator.free(tt);
            },
            .jwt => |*jwt| {
                if (jwt.public_key) |pk| self.allocator.free(pk);
                if (jwt.audience) |a| self.allocator.free(a);
                if (jwt.issuer) |i| self.allocator.free(i);
            },
            .oauth2 => |*oauth| {
                if (oauth.refresh_token) |rt| self.allocator.free(rt);
                if (oauth.scope) |s| self.allocator.free(s);
            },
            .hmac_sha256 => |*hmac_ctx| {
                self.allocator.free(hmac_ctx.key_id);
                self.allocator.free(hmac_ctx.secret_key);
                self.allocator.free(hmac_ctx.key_id_header);
                self.allocator.free(hmac_ctx.signature_header);
            },
            .api_key => |*api_key| {
                self.allocator.free(api_key.api_key);
                self.allocator.free(api_key.header_name);
                if (api_key.prefix) |p| self.allocator.free(p);
            },
        }
    }
    
    /// Get the authentication header for the current authentication method
    pub fn getAuthHeader(self: *AuthManager) ![]const u8 {
        switch (self.config) {
            .token => |*token| {
                if (self.isTokenExpired(token.expiry)) {
                    try self.refreshToken();
                }
                
                if (token.token_type) |token_type| {
                    return fmt.allocPrint(
                        self.allocator,
                        "{s} {s}",
                        .{ token_type, token.token }
                    );
                } else {
                    return fmt.allocPrint(
                        self.allocator,
                        "Bearer {s}",
                        .{token.token}
                    );
                }
            },
            .jwt => |jwt| {
                // In a real implementation, we would validate the JWT here
                return fmt.allocPrint(
                    self.allocator,
                    "Bearer {s}",
                    .{jwt.token}
                );
            },
            .oauth2 => |oauth| {
                return fmt.allocPrint(
                    self.allocator,
                    "{s} {s}",
                    .{ oauth.token_type, oauth.access_token }
                );
            },
            .hmac_sha256 => |_| {
                // This is just a mock implementation
                _ = self.allocator; // Mark as used
                return "";
            },
            .api_key => |api_key| {
                if (api_key.prefix) |prefix| {
                    return fmt.allocPrint(
                        self.allocator,
                        "{s}{s}",
                        .{ prefix, api_key.api_key }
                    );
                } else {
                    return api_key.api_key;
                }
            },
        }
    }
    
    /// Add authentication headers to a request
    pub fn addAuthHeaders(
        self: *AuthManager,
        headers: *std.http.Headers,
    ) !void {
        switch (self.config) {
            .token, .jwt, .oauth2 => {
                const header = try self.getAuthHeader();
                defer self.allocator.free(header);
                try headers.append("Authorization", header);
            },
            .hmac_sha256 => |_| {
                const header = try self.getAuthHeader();
                defer self.allocator.free(header);
                
                // Split the header into key: value pairs
                var it = std.mem.split(u8, header, "\n");
                while (it.next()) |line| {
                    var parts = std.mem.split(u8, line, ": ");
                    if (parts.next()) |key| {
                        if (parts.next()) |value| {
                            try headers.append(key, value);
                        }
                    }
                }
            },
            .api_key => |api_key| {
                const value = if (api_key.prefix) |prefix|
                    try fmt.allocPrint(self.allocator, "{s}{s}", .{
                        prefix, api_key.api_key
                    })
                else
                    api_key.api_key;
                
                defer if (api_key.prefix != null) self.allocator.free(value);
                
                try headers.append(api_key.header_name, value);
            },
        }
    }
    
    /// Check if the current token is expired
    fn isTokenExpired(self: *const AuthManager, expiry: i64) bool {
        _ = self; // Unused parameter
        if (expiry == 0) return false;
        return time.timestamp() >= expiry;
    }
    
    /// Refresh the authentication token
    fn refreshToken(self: *AuthManager) !void {
        // In a real implementation, this would make an HTTP request to the auth server
        // For now, we'll just update the timestamp
        self.last_refresh = time.timestamp();
        
        // If we have a refresh token, we would use it here
        switch (self.config) {
            .token => |*token| {
                if (token.refresh_token != null) {
                    // TODO: Implement token refresh logic
                }
            },
            .oauth2 => |*oauth| {
                if (oauth.refresh_token != null) {
                    // TODO: Implement OAuth2 token refresh
                }
            },
            else => {},
        }
    }
    
    /// Validate a JWT token
    pub fn validateToken(
        self: *const AuthManager,
        token: []const u8,
        options: struct {
            leeway: u64 = 60,
        },
    ) !void {
        _ = self; // Mark as used for future implementation
        _ = options.leeway; // Mark as used for future implementation
        
        // In a real implementation, this would verify the JWT signature
        // and validate the claims (exp, nbf, iss, aud, etc.)
        // For now, we'll just check if the token is not empty
        if (token.len == 0) {
            return error.InvalidToken;
        }
    }
};

test "auth manager" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const config = AuthConfig{
        .token = "test_token_123",
        .token_expiry = std.time.timestamp() + 3600, // 1 hour from now
    };
    
    var auth = AuthManager.init(arena.allocator(), config);
    const header = try auth.getAuthHeader();
    
    try std.testing.expect(std.mem.startsWith(u8, header, "Bearer "));
    try std.testing.expect(!auth.isTokenExpired());
}
