import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class PlatformerGame extends FlameGame with TapCallbacks, DragCallbacks {
  // Player Variables
  late Vector2 playerPos;
  late Vector2 playerVel;
  final Vector2 playerSize = Vector2(30, 40);
  bool isGrounded = false;
  int lives = 3;
  int score = 0;
  bool isGameOver = false;

  // Physics
  final double gravity = 900.0;
  final double moveSpeed = 200.0;
  final double jumpForce = -420.0;

  // Touch Movement Input
  double horizontalInput = 0.0;

  // Level Entities
  List<Rect> staticPlatforms = [];
  late MovingPlatform movingPlatform;
  List<Rect> coins = [];
  late PatrollingEnemy enemy;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    initGame();
  }

  void initGame() {
    lives = 3;
    score = 0;
    isGameOver = false;
    horizontalInput = 0.0;

    // Initialize Player Position
    playerPos = Vector2(50, size.y - 120);
    playerVel = Vector2.zero();

    // Static Ground & Platforms
    staticPlatforms = [
      Rect.fromLTWH(0, size.y - 40, size.x, 40), // Ground
      Rect.fromLTWH(60, size.y - 140, 120, 20),
      Rect.fromLTWH(260, size.y - 240, 140, 20),
      Rect.fromLTWH(80, size.y - 340, 120, 20),
    ];

    // Moving Platform (oscillates horizontally)
    movingPlatform = MovingPlatform(
      rect: Rect.fromLTWH(200, size.y - 180, 100, 18),
      minX: 160,
      maxX: 340,
      speed: 80,
    );

    // Collectible Coins
    coins = [
      Rect.fromLTWH(100, size.y - 180, 18, 18),
      Rect.fromLTWH(310, size.y - 280, 18, 18),
      Rect.fromLTWH(130, size.y - 380, 18, 18),
      Rect.fromLTWH(240, size.y - 210, 18, 18),
    ];

    // Patrolling Enemy (patrols back and forth on ground)
    enemy = PatrollingEnemy(
      pos: Vector2(250, size.y - 70),
      size: Vector2(30, 30),
      minX: 180,
      maxX: size.x - 60,
      speed: 100,
    );
  }

  // ---------------------------------------------------------------------------
  // TOUCH CONTROLS (Screen Buttons & Tap-to-Jump)
  // ---------------------------------------------------------------------------
  @override
  void onTapDown(TapDownEvent event) {
    if (isGameOver) {
      initGame();
      return;
    }

    final tapPos = event.canvasPosition;

    // Check on-screen controls
    if (tapPos.y > size.y - 100) {
      if (tapPos.x < 90) {
        horizontalInput = -1.0; // Left
      } else if (tapPos.x > 100 && tapPos.x < 190) {
        horizontalInput = 1.0; // Right
      } else if (tapPos.x > size.x - 120 && isGrounded) {
        playerVel.y = jumpForce; // Jump
        isGrounded = false;
      }
    } else if (isGrounded) {
      playerVel.y = jumpForce;
      isGrounded = false;
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    horizontalInput = 0.0;
  }

  // ---------------------------------------------------------------------------
  // UPDATE LOOP & COLLISIONS
  // ---------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    // Update Moving Platform & Enemy
    movingPlatform.update(dt);
    enemy.update(dt);

    // Apply Velocity & Gravity
    playerVel.x = horizontalInput * moveSpeed;
    playerVel.y += gravity * dt;

    playerPos.x += playerVel.x * dt;
    playerPos.x = playerPos.x.clamp(0.0, size.x - playerSize.x);

    playerPos.y += playerVel.y * dt;

    // Platform Collisions
    isGrounded = false;
    final playerRect = Rect.fromLTWH(playerPos.x, playerPos.y, playerSize.x, playerSize.y);

    // Static Platforms Collision
    for (final platform in staticPlatforms) {
      if (playerRect.overlaps(platform) && playerVel.y > 0 && (playerPos.y + playerSize.y - playerVel.y * dt) <= platform.top + 10) {
        playerPos.y = platform.top - playerSize.y;
        playerVel.y = 0;
        isGrounded = true;
      }
    }

    // Moving Platform Collision & Transport
    if (playerRect.overlaps(movingPlatform.rect) && playerVel.y > 0 && (playerPos.y + playerSize.y - playerVel.y * dt) <= movingPlatform.rect.top + 10) {
      playerPos.y = movingPlatform.rect.top - playerSize.y;
      playerPos.x += movingPlatform.velocity * dt; // Transport player along
      playerVel.y = 0;
      isGrounded = true;
    }

    // Coin Collection Collision
    for (int i = coins.length - 1; i >= 0; i--) {
      if (playerRect.overlaps(coins[i])) {
        coins.removeAt(i);
        score += 25;
      }
    }

    // Enemy Collision Check (Loses a life)
    if (playerRect.overlaps(enemy.rect)) {
      lives--;
      if (lives <= 0) {
        isGameOver = true;
      } else {
        // Respawn player at start position
        playerPos = Vector2(50, size.y - 120);
        playerVel = Vector2.zero();
      }
    }

    // Fall Off Bottom Screen Boundary Reset
    if (playerPos.y > size.y) {
      lives--;
      if (lives <= 0) {
        isGameOver = true;
      } else {
        playerPos = Vector2(50, size.y - 120);
        playerVel = Vector2.zero();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CANVAS RENDERING
  // ---------------------------------------------------------------------------
  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Draw Static Platforms
    final Paint platformPaint = Paint()..color = const Color(0xFF475569);
    for (final platform in staticPlatforms) {
      canvas.drawRRect(RRect.fromRectAndRadius(platform, const Radius.circular(4)), platformPaint);
    }

    // 2. Draw Moving Platform
    final Paint movingPaint = Paint()..color = const Color(0xFF0284C7);
    canvas.drawRRect(RRect.fromRectAndRadius(movingPlatform.rect, const Radius.circular(4)), movingPaint);

    // 3. Draw Collectible Coins
    final Paint coinPaint = Paint()..color = const Color(0xFFF59E0B);
    for (final coin in coins) {
      canvas.drawCircle(coin.center, coin.width / 2, coinPaint);
    }

    // 4. Draw Patrolling Enemy
    final Paint enemyPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRect(enemy.rect, enemyPaint);

    // 5. Draw Player Character
    final Paint playerPaint = Paint()..color = const Color(0xFF22C55E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(playerPos.x, playerPos.y, playerSize.x, playerSize.y),
        const Radius.circular(6),
      ),
      playerPaint,
    );

    // 6. Draw HUD (Score & Lives)
    final TextPainter hudText = TextPainter(
      text: TextSpan(
        text: 'Score: $score  \vert{}  Lives:${"❤️ " * lives}',
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    hudText.layout();
    hudText.paint(canvas, const Offset(20, 45));

    // 7. Draw On-Screen Touch Control Buttons
    final Paint btnPaint = Paint()..color = Colors.white.withOpacity(0.25);

    // Left Arrow Button
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(20, size.y - 90, 70, 60), const Radius.circular(8)), btnPaint);
    // Right Arrow Button
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(100, size.y - 90, 70, 60), const Radius.circular(8)), btnPaint);
    // Jump Button
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.x - 100, size.y - 90, 80, 60), const Radius.circular(8)), btnPaint);

    // 8. Render Game Over Screen Overlay
    if (isGameOver) {
      final Paint overlayPaint = Paint()..color = Colors.black.withOpacity(0.8);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), overlayPaint);

      final TextPainter gameOverText = TextPainter(
        text: TextSpan(
          text: 'GAME OVER\nFinal Score: $score\n\nTap to Restart',
          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 28, fontWeight: FontWeight.bold, height: 1.4),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      gameOverText.layout();
      gameOverText.paint(canvas, Offset((size.x - gameOverText.width) / 2, (size.y - gameOverText.height) / 2));
    }
  }
}

// -----------------------------------------------------------------------------
// HELPER CLASSES (Moving Platform & Enemy)
// -----------------------------------------------------------------------------
class MovingPlatform {
  Rect rect;
  double minX;
  double maxX;
  double speed;
  double velocity;

  MovingPlatform({required this.rect, required this.minX, required this.maxX, required this.speed}) : velocity = speed;

  void update(double dt) {
    rect = rect.translate(velocity * dt, 0);
    if (rect.left <= minX) velocity = speed.abs();
    if (rect.right >= maxX) velocity = -speed.abs();
  }
}

class PatrollingEnemy {
  Vector2 pos;
  Vector2 size;
  double minX;
  double maxX;
  double speed;
  double velocity;

  PatrollingEnemy({required this.pos, required this.size, required this.minX, required this.maxX, required this.speed}) : velocity = speed;

  Rect get rect => Rect.fromLTWH(pos.x, pos.y, size.x, size.y);

  void update(double dt) {
    pos.x += velocity * dt;
    if (pos.x <= minX) velocity = speed.abs();
    if (pos.x >= maxX - size.x) velocity = -speed.abs();
  }
}