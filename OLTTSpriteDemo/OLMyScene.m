//
//  OLMyScene.m
//  OLTTSpriteDemo
//
//  Created by Ali Shahriyari on 8/19/13.
//  Copyright (c) 2013 Originate. All rights reserved.
//

// NOTE: BAREBONES DEMO OF SPRITE KIT USING THE ADVENTURE GAME FROM APPLE.
// MOST CODE IS PLACED HERE IN ONE CLASS AS A QUICK AND EASY REFERENCE TO UNDERSTAND SPRITE KIT.

#import "OLMyScene.h"
#import "OLAntagonist.h"

// Layer the world so everything shows up in the right Z order
typedef enum : uint8_t {
	WorldLayerGround = 0,
	WorldLayerCharacter,
	WorldLayerAboveCharacter,
  WorldLayerScoreboard,
	kWorldLayerCount
} WorldLayer;

// Collision bitmasks
typedef enum : uint8_t {
  ColliderTypeHero        = 1,
  ColliderTypeAntagonist  = 2,
  ColliderTypeProjectile  = 4,
} ColliderType;

// Some constants
const NSTimeInterval kAnimationSpeed = 1 / 28.0;
const float kMovementSpeed = 200.0;
const int kInitialHeroHealth = 5;

@interface OLMyScene () <SKPhysicsContactDelegate> {
  // World
  SKNode *_world;
  NSMutableArray *_layers;
  NSArray *_groundTiles;
  
  // Scoreboard
  SKLabelNode *_healthStatus;
  SKLabelNode *_numberOfKills;
  
  // Hero
  SKSpriteNode *_hero;
  NSArray *_heroIdle;
  NSArray *_heroWalk;
  NSArray *_heroAttack;
  NSArray *_heroDeath;
  CGPoint _heroNewTargetLocation;
  BOOL _heroIsAnimating;
  BOOL _heroIsAttacking;
  BOOL _heroIsDead;
  int _heroHealth;
  int _killCount;
  
  // Antagonists!
  NSMutableArray *_antagonists;
  NSArray *_goblinWalk;
  NSArray *_goblinAttack;
  NSArray *_internWalk;
  NSArray *_internAttack;
  NSTimeInterval _lastAntagonistsGenerationTimeInterval;
  
  // Tardy air support
  SKSpriteNode *_spaceship;
  BOOL _launchedSpaceship;
  
  // Particle files
  SKEmitterNode *_bomb;
  SKEmitterNode *_spark;
  SKEmitterNode *_afterburner;
  SKEmitterNode *_archerProjectile;
  
  // Animation time tracker
  NSTimeInterval _lastUpdateTimeInterval;
}
@end

@implementation OLMyScene

-(id)initWithSize:(CGSize)size {
  if (self = [super initWithSize:size]) {
    
    // NOTE: For a real app, should be showing a loading type animation here
    [self loadWorldData];
    
    // Set physics in our world
    self.physicsWorld.gravity = CGPointZero;
    self.physicsWorld.contactDelegate = self;
    
    // World node.  Everything is attached to this node
    _world = [[SKNode alloc] init];
    
    // Our layers
    _layers = [NSMutableArray arrayWithCapacity:kWorldLayerCount];
    for (int i = 0; i < kWorldLayerCount; i++) {
      SKNode *layer = [[SKNode alloc] init];
      layer.zPosition = i - kWorldLayerCount;
      [_world addChild:layer];
      [_layers addObject:layer];
    }
    
    // Create scoreboard labels, set initial text, and add to bottom left of screen
    _healthStatus = [SKLabelNode labelNodeWithFontNamed:@"helvetica"];
    _numberOfKills = [SKLabelNode labelNodeWithFontNamed:@"helvetica"];
    _healthStatus.fontColor = _numberOfKills.fontColor = [SKColor blackColor];
    _healthStatus.fontSize = _numberOfKills.fontSize = 30;
    _healthStatus.horizontalAlignmentMode = _numberOfKills.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    _healthStatus.text = [NSString stringWithFormat:@"Health: %d", kInitialHeroHealth];
    _healthStatus.position = CGPointMake(self.frame.origin.x + 20, 540);
    _numberOfKills.text = @"Kills: 0";
    _numberOfKills.position = CGPointMake(self.frame.origin.x + 20, 500);

    // Create our Hero using idle mode image texture, set collision physics and center in screen
    _hero = [SKSpriteNode spriteNodeWithTexture:[_heroIdle firstObject]];
    _hero.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:5];
    _hero.physicsBody.collisionBitMask = ColliderTypeAntagonist;
    _hero.physicsBody.categoryBitMask = ColliderTypeHero;
    _hero.position = _heroNewTargetLocation = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    _heroHealth = kInitialHeroHealth;
    
    // Create list for our Antagonists
    _antagonists = [[NSMutableArray alloc] init];
    
    // Add ground tiles to the ground layer (They are already positioned)
    for (SKNode *tileNode in _groundTiles) {
      SKNode *layerNode = _layers[WorldLayerGround];
      [layerNode addChild:tileNode];
    }
    
    // Hero goes next on the character layer
    SKNode *layerNode = _layers[WorldLayerCharacter];
    [layerNode addChild:_hero];
    
    // Scoreboard labels go next on to the scoreboard layer
    layerNode = _layers[WorldLayerScoreboard];
    [layerNode addChild:_healthStatus];
    [layerNode addChild:_numberOfKills];
    
    // Add our world to the scene
    [self addChild:_world];
  }
  
  return self;
}

# pragma mark - User Interaction

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  UITouch *touch = [touches anyObject];
  NSArray *nodes = [self nodesAtPoint:[touch locationInNode:self]];
  
  // Check to see if Antagonist was clicked
  for (SKNode *node in nodes) {
    // Antagonist was clicked
    //if (node.physicsBody.categoryBitMask & ColliderTypeAntagonist) {
    if ([node isKindOfClass:[OLAntagonist class]]) {
      // Stop hero from walking any further and set isAttacking flag
      _heroNewTargetLocation = _hero.position;
      _heroIsAttacking = YES;
      
      // Turn hero towards target
      CGFloat ang = radiansBetweenPoints(node.position, _hero.position) + (M_PI * 0.5f);
      _hero.zRotation = ang;
      
      return;
    }
  }
  
  // No Antagonist clicked, set new Hero destination
  _heroNewTargetLocation = [touch locationInNode:_hero.parent];
}

#pragma mark - Loop Update

- (void)update:(NSTimeInterval)currentTime {
  // Update time info
  CFTimeInterval timeSinceLastUpdate = currentTime - _lastUpdateTimeInterval;
  _lastUpdateTimeInterval = currentTime;
  if (timeSinceLastUpdate > 1)
    timeSinceLastUpdate = (1.0f / 60.0f);
  
  // Update Hero
  if (!_heroIsDead)
    [self updateHero:timeSinceLastUpdate];

  // Create More Antagonists
  if (!_heroIsDead && currentTime - _lastAntagonistsGenerationTimeInterval > 2) {
    _lastAntagonistsGenerationTimeInterval = currentTime;
    [self createMoreAntagonists];
  }

  // Update Antagonists
  [self updateAntagonists:timeSinceLastUpdate];
  
  // Launch spaceship if Hero is dead
  if (_heroIsDead && !_launchedSpaceship) {
    _launchedSpaceship = true;
    [self launchSpaceship];
  }
}

-(void)updateHero:(CFTimeInterval) timeSinceLastUpdate {
  if (!_heroIsAnimating) {
    _heroIsAnimating = true;
    
    // Hero dead animation
    if (_heroHealth <= 0) {
      [_hero runAction:[SKAction sequence:@[[SKAction animateWithTextures:_heroDeath timePerFrame:kAnimationSpeed resize:YES restore:NO],
                                            [SKAction fadeOutWithDuration:4],
                                            [SKAction runBlock:^{[self heroAnimationHasCompleted];}],
                                            [SKAction runBlock:^{[self showEndGameMessage];}],
                                            [SKAction removeFromParent]
                                            ]]];
      _heroIsDead = true;
      _hero.physicsBody = nil;
    }
    // Hero is attacking
    else if (_heroIsAttacking) {
      _heroIsAttacking = false;
      [_hero runAction:[SKAction sequence:@[[SKAction animateWithTextures:_heroAttack timePerFrame:kAnimationSpeed resize:YES restore:YES],
                                            [SKAction runBlock:^{[self heroAnimationHasCompleted];}],
                                            [SKAction runBlock:^{[self fireAtAntagonist];}]
                                            ]]];
    }
    // Hero idle animation
    else if (distanceBetweenTwoPoints(_heroNewTargetLocation, _hero.position) < 100)
      [_hero runAction:[SKAction sequence:@[[SKAction animateWithTextures:_heroIdle timePerFrame:kAnimationSpeed resize:YES restore:YES],
                                            [SKAction runBlock:^{[self heroAnimationHasCompleted];}]]]];
    // Hero walk animation
    else
      [_hero runAction:[SKAction sequence:@[[SKAction animateWithTextures:_heroWalk timePerFrame:kAnimationSpeed resize:YES restore:YES],
                                            [SKAction runBlock:^{[self heroAnimationHasCompleted];}]]]];
  }
  
  // Move Hero to target location if needed
  if (!CGPointEqualToPoint(_heroNewTargetLocation, _hero.position))
    [self moveNode:_hero location:_heroNewTargetLocation timeInterval:timeSinceLastUpdate];
}

- (void)updateAntagonists:(CFTimeInterval)timeSinceLastUpdate {
  for (OLAntagonist *antagonist in _antagonists) {
    if (!antagonist.isDeadOrHiding) {
      if (!antagonist.isAnimating) {
        antagonist.isAnimating = true;
        
        // Antagonist attack animation
        if (distanceBetweenTwoPoints(antagonist.position, _hero.position) < 100) {
          _heroHealth--;
          _healthStatus.text = [NSString stringWithFormat:@"Health: %d", _heroHealth > 0 ? _heroHealth : 0];
          [antagonist runAction:[SKAction sequence:@[[SKAction animateWithTextures:antagonist.isIntern ? _internAttack : _goblinAttack timePerFrame:kAnimationSpeed resize:YES restore:YES],
                                                     [SKAction runBlock:^{[self antagonistAnimationHasCompleted:antagonist];}]]]];
        }
        // Antagonist walk animation
        else
          [antagonist runAction:[SKAction sequence:@[[SKAction animateWithTextures:antagonist.isIntern ? _internWalk : _goblinWalk timePerFrame:kAnimationSpeed resize:YES restore:YES],
                                                     [SKAction runBlock:^{[self antagonistAnimationHasCompleted:antagonist];}]]]];
      }
      
      // Run away and hide from spaceship if Hero is dead!
      if (_heroIsDead) {
        // Hide!
        if (distanceBetweenTwoPoints(antagonist.position, antagonist.initialPosition) < 100) {
          [antagonist removeFromParent];
          antagonist.isDeadOrHiding = true;
        }
        // Run
        else
          [self moveNode:antagonist location:antagonist.initialPosition timeInterval:timeSinceLastUpdate/3];
      }
      // Move Antagonists towards Hero if Hero is alive and we are not near the Hero
      else if (!_heroIsDead && (distanceBetweenTwoPoints(antagonist.position, _hero.position) > 100))
        [self moveNode:antagonist location:_hero.position timeInterval:antagonist.isFaster ? timeSinceLastUpdate * 2 : timeSinceLastUpdate/3];
    }
  }
}

#pragma mark - Physics Delegate

- (void)didBeginContact:(SKPhysicsContact *)contact {
  SKNode *bodyA = contact.bodyA.node;
  SKNode *bodyB = contact.bodyB.node;

  // Check for Hero projectile to Antagonist collision.  If found, blow up Antagonist
  if ([bodyA isKindOfClass:[SKEmitterNode class]] && [bodyB isKindOfClass:[OLAntagonist class]])
    [self blowUpAntagonist:(OLAntagonist *)bodyB];
  else if ([bodyB isKindOfClass:[SKEmitterNode class]] && [bodyA isKindOfClass:[OLAntagonist class]])
    [self blowUpAntagonist:(OLAntagonist *)bodyA];
}

#pragma mark - Animation Completion Callbacks

- (void)heroAnimationHasCompleted {
  _heroIsAnimating = false;
}

- (void)antagonistAnimationHasCompleted:(OLAntagonist*)antagonist {
  antagonist.isAnimating = false;
}

#pragma mark - End Game Message

-(void)showEndGameMessage {
  // Create message, set initial text, and add to center of screen
  SKLabelNode *endGameMessage = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
  endGameMessage.color = [SKColor blackColor];
  endGameMessage.fontSize = 50;
  endGameMessage.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
  endGameMessage.text = @"DEMO OVER!";
  
  // Add message to scoreboard layer
  SKNode *layerNode = _layers[WorldLayerScoreboard];
  [layerNode addChild:endGameMessage];
}

#pragma mark - Creation/Destruction of Antagonists

- (void)createMoreAntagonists {
  OLAntagonist *antagonist;
  if (arc4random_uniform(10) == 0) { // Sometimes our Antagonist is an intern
    antagonist = [[OLAntagonist alloc] initWithTexture:[_internWalk firstObject]];
    antagonist.isIntern = true;
  }
  else
    antagonist = [[OLAntagonist alloc] initWithTexture:[_goblinWalk firstObject]];
  
  // Set collision physics
  antagonist.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:50];
  antagonist.physicsBody.categoryBitMask = ColliderTypeAntagonist;
  antagonist.physicsBody.collisionBitMask = ColliderTypeProjectile | ColliderTypeAntagonist | ColliderTypeHero;
  antagonist.physicsBody.contactTestBitMask = ColliderTypeProjectile;
  
  // Position Antagonist
  if (arc4random_uniform(4) == 0)
    antagonist.initialPosition = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame) + 1000);
  else if (arc4random_uniform(4) == 1)
    antagonist.initialPosition = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame) - 1000);
  else if (arc4random_uniform(4) == 2)
    antagonist.initialPosition = CGPointMake(CGRectGetMidX(self.frame) + 1000, CGRectGetMidY(self.frame));
  else {
    antagonist.initialPosition = CGPointMake(CGRectGetMidX(self.frame) - 1000, CGRectGetMidY(self.frame));
    antagonist.isFaster = true;
  }
  
  // Add Antagonist to the character layer in our world
  SKNode *layerNode = _layers[WorldLayerCharacter];
  [layerNode addChild:antagonist];
  
  // Add Antagonist to our list
  [_antagonists addObject:antagonist];
}

-(void)fireAtAntagonist {
  // Create a Hero Projectile
  SKEmitterNode *archerProjectile = [_archerProjectile copy];
  archerProjectile.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:15];
  archerProjectile.physicsBody.categoryBitMask = ColliderTypeProjectile;
  archerProjectile.physicsBody.collisionBitMask = ColliderTypeAntagonist;
  archerProjectile.physicsBody.contactTestBitMask = ColliderTypeAntagonist;
  archerProjectile.targetNode = _world;
  
  // Position Hero projectile
  archerProjectile.position = _hero.position;
  archerProjectile.zRotation = _hero.zRotation;

  // Add Hero projectile to the character layer in our world
  SKNode *layerNode = _layers[WorldLayerCharacter];
  [layerNode addChild:archerProjectile];
  
  // Launch projectile
  CGFloat rot = _hero.zRotation;
  [archerProjectile runAction:[SKAction sequence:@[[SKAction moveByX:-sinf(rot)*5*kMovementSpeed y:cosf(rot)*5*kMovementSpeed duration:2],
                                                   [SKAction removeFromParent]]]];
}

-(void)killAllAntagonists {
  for (OLAntagonist *antagonist in _antagonists)
    if (!antagonist.isDeadOrHiding)
      [self blowUpAntagonist:antagonist];
}

- (void)blowUpAntagonist:(OLAntagonist *)antagonist {
  antagonist.isDeadOrHiding = true;
  antagonist.physicsBody = nil;
  
  // Add bomb particle to run for 5 seconds
  SKEmitterNode *bomb = [_bomb copy];
  bomb.position = antagonist.position;
  [antagonist.parent addChild:bomb];
  [antagonist removeFromParent];
  [bomb runAction:[SKAction sequence:@[[SKAction fadeOutWithDuration: 5], [SKAction removeFromParent]]]];
  
  // Add initial spark to run for 1 second
  SKEmitterNode *spark = [_spark copy];
  spark.position = bomb.position;
  [bomb.parent addChild:spark];
  [spark runAction:[SKAction sequence:@[[SKAction fadeOutWithDuration: 1], [SKAction removeFromParent]]]];
  
  // Update scoreboard
  _killCount++;
  _numberOfKills.text = [NSString stringWithFormat:@"Kills: %d", _killCount];
}

#pragma mark - Launch Spaceship

-(void)launchSpaceship {
  _spaceship = [SKSpriteNode spriteNodeWithImageNamed:@"Spaceship"];
  
  // Add some cool effects to our spaceship
  SKEmitterNode *afterburner = [_afterburner copy];
  afterburner.position = CGPointMake(afterburner.position.x, afterburner.position.y - 180);;
  [_spaceship addChild:afterburner];
  
  // Set initial position
  _spaceship.position = CGPointMake(CGRectGetMidX(self.frame) - 1000, CGRectGetMidY(self.frame));
  
  // Add Spaceship to above character layer
  SKNode *layerNode = _layers[WorldLayerAboveCharacter];
  [layerNode addChild:_spaceship];
  
  // Calculate travel path for our spaceship
  CGMutablePathRef path = CGPathCreateMutable();
  CGPathMoveToPoint(path, nil, _spaceship.position.x, _spaceship.position.y);
  
  int maxX = CGRectGetMidX(self.frame);
  int minX = CGRectGetMidX(self.frame);
  int maxY = CGRectGetMidY(self.frame);
  int minY = CGRectGetMidY(self.frame);
  
  for (OLAntagonist *antagonist in _antagonists) {
    if (!antagonist.isDeadOrHiding) {
      if (antagonist.position.x > maxX)
        maxX = antagonist.position.x;
      if (antagonist.position.x < minX)
        minX = antagonist.position.x;
      if (antagonist.position.y > maxY)
        maxY = antagonist.position.y;
      if (antagonist.position.y < minY)
        minY = antagonist.position.y;
    }
  }
  
  CGPathAddCurveToPoint(path, nil, maxX, maxY, minX, minY, CGRectGetMidX(self.frame) + 1200, CGRectGetMidY(self.frame));
  
  // Launch spaceship
  [_spaceship runAction:[SKAction group:@[[SKAction followPath:path asOffset:false orientToPath:YES duration:4],
                                          [SKAction sequence:@[[SKAction waitForDuration: 2],
                                                               [SKAction runBlock:^{[self killAllAntagonists];}],
                                                               [SKAction waitForDuration: 2],
                                                               [SKAction removeFromParent]]]]]];
  
  // Done using path
  CGPathRelease(path);
}

#pragma mark - Load Data From Disk

- (void)loadWorldData {
  // Load the ground
  _groundTiles = [self loadGroundTiles];
  
  // Load Hero, Goblin, Intern atlas data
  _heroIdle = [self loadCharacterAtlas:@"Archer_Idle"];
  _heroWalk = [self loadCharacterAtlas:@"Archer_Walk"];
  _heroAttack = [self loadCharacterAtlas:@"Archer_Attack"];
  _heroDeath = [self loadCharacterAtlas:@"Archer_Death"];
  _goblinWalk = [self loadCharacterAtlas:@"Goblin_Walk"];
  _goblinAttack = [self loadCharacterAtlas:@"Goblin_Attack"];
  _internWalk = [self loadCharacterAtlas:@"Intern_Walk"];
  _internAttack = [self loadCharacterAtlas:@"Intern_Attack"];
  
  // Load particle files from disk
  _bomb = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"Bomb" ofType:@"sks"]];
  _spark = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"Spark" ofType:@"sks"]];
  _afterburner = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"Afterburner" ofType:@"sks"]];
  _archerProjectile = [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"ArcherProjectile" ofType:@"sks"]];
}

- (NSArray*)loadCharacterAtlas:(NSString*)atlasName {
  NSMutableArray *frames = [NSMutableArray array];
  SKTextureAtlas *atlas = [SKTextureAtlas atlasNamed:atlasName]; 
  
  for (int i = 1; i < atlas.textureNames.count + 1; i++) {
    NSString* texture = [NSString stringWithFormat:@"%@_%04d", [atlasName lowercaseString], i];
    [frames addObject:[atlas textureNamed:texture]];
  }
  
  return frames;
}

- (NSArray*)loadGroundTiles {
  NSMutableArray *tiles = [[NSMutableArray alloc] init];
  SKTextureAtlas *atlas = [SKTextureAtlas atlasNamed:@"Tiles"];

  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      int tileNumber = (y * 8) + x;
      SKSpriteNode *tileNode = [SKSpriteNode spriteNodeWithTexture:[atlas textureNamed:[NSString stringWithFormat:@"tile%d.png", tileNumber]]];
      CGPoint position = CGPointMake((x * 256) , (((8-y) * 256)));
      tileNode.position = position;
      tileNode.xScale = 2;
      tileNode.yScale = 2;
      [tiles addObject:tileNode];
    }
  }
  
  return tiles;
}
   
# pragma mark - Math Helper Methods With Some From Adventure Game

- (void)moveNode:(SKSpriteNode*)node location:(CGPoint)position timeInterval:(NSTimeInterval)timeInterval {
  CGPoint curPosition = node.position;
  CGFloat dx = position.x - curPosition.x;
  CGFloat dy = position.y - curPosition.y;
  CGFloat dt = kMovementSpeed * timeInterval;
 
  CGFloat ang = radiansBetweenPoints(position, curPosition) + (M_PI * 0.5f);
  node.zRotation = ang;
 
  CGFloat distRemaining = hypotf(dx, dy);
  if (distRemaining < dt)
    node.position = position;
  else
    node.position = CGPointMake(curPosition.x - sinf(ang) * dt, curPosition.y + cosf(ang) * dt);
}
   
CGFloat radiansBetweenPoints(CGPoint first, CGPoint second) {
  CGFloat deltaX = second.x - first.x;
  CGFloat deltaY = second.y - first.y;
  return atan2f(deltaY, deltaX);
}

CGFloat distanceBetweenTwoPoints(CGPoint point1,CGPoint point2)
{
  CGFloat dx = point2.x - point1.x;
  CGFloat dy = point2.y - point1.y;
  return sqrt(dx*dx + dy*dy);
}
   
@end
