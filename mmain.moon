require 'libs/autobatch'
F = require 'libs/moses'  -- F for Functional
L = require 'libs/lume'  -- L for Lume
import random from L
Object = require 'libs/classic'
Timer = require 'libs/timer'
Input = require 'libs/boipushy'
GameState = require 'libs/gamestate'
ECS = require 'libs/tiny_ecs'
Vector = require 'libs/vector'
Bump = require 'libs/bump'
DebugGraph = require 'libs/debug_graph'
BumpDebug = require 'libs/bump_debug'
Observer = require 'libs/talkback'
Shake = require 'libs/shack'
-- Pie = (require 'libs/piefiller')\new!
Utils = require 'libs/utils'

Talk = Observer.new!

{graphics: lg, math: lm} = love

setmetatable _G, __index: require('libs/cargo').init
    dir: 'assets'
    processors:
        ['images/']: (image, file_name) ->
            image\setFilter 'nearest'

export DEBUG = true
export SHOW_WEAPONS = true

export SCREEN_X0 = 0
export SCREEN_Y0 = 0
export SCREEN_W = 150
export SCREEN_H = 200

WHITE = {255, 255, 255}
DEBUG_RED = {255, 150, 150}
GREEN = {106, 190, 48}
RED = {172, 50, 50}
DARK_BLUE = {34, 32, 52}

tableToArray = (t) -> [v for k, v in pairs t]

getCenterPosition = -> Vector SCREEN_W / 2, SCREEN_H / 2

Entity = (components) ->
    for i = 1, #components
        component = components[i]
        components[component] = true
        components[i] = nil

    components.new = (t = {}) =>
        entity = Utils.deepCopy @
        entity[k] = v for k, v in pairs t

        for i = 1, #t
            component = t[i]
            entity[component] = true
            entity[i] = nil

        return entity
    setmetatable components, __call: (t) => @\new t

    components.timer = Timer!
    components.existing_time = 0

    components.getCenter = =>
        if @bounding_box then return @position + Vector @bounding_box.w / 2, @bounding_box.h / 2
        else return @position\clone!

    return components

Weapon = Entity {
    'weapon'
    name: 'unnamed weapon'
    shoot_time: 0
    down: (dt) =>
        @shoot_time += dt
        if @shoot_time >= @fire_rate
            @shoot @world, @owner
            @shoot_time -= @fire_rate
}

WeaponPickup = Entity {
    'weapon_pickup'
    'die_in_bottom_of_screen'
    position: getCenterPosition!
    velocity: Vector 0, 30
    bounding_box: w: 9, h: 9
    weapon: nil
    draw: =>
        assert @weapon, 'Invalid WeaponPickup instance, need weapon.'

        lg.setColor WHITE
        lg.setLineWidth 0.5
        lg.polygon 'line', @position.x + @bounding_box.w / 2, @position.y, @position.x + @bounding_box.w, @position.y + @bounding_box.h / 2,
                           @position.x + @bounding_box.w / 2, @position.y + @bounding_box.h, @position.x, @position.y + @bounding_box.h / 2
        lg.setLineWidth 1
        lg.rectangle 'line', @position.x, @position.y, @bounding_box.w, @bounding_box.h
}

Bullet = Entity {
    'bullet'
    'die_in_top_of_screen'
    position: Vector SCREEN_W / 2, SCREEN_H / 2
}

bullets = {}

bullets.Normal = Bullet {
    power: 20
    velocity: Vector 0, -300
    bounding_box: w:3, h:3
    draw: =>
        lg.setColor WHITE
        lg.circle 'fill', @position.x + 1.5, @position.y + 1.5, 2
}

bullets.Side = bullets.Normal {
    velocity: Vector -200, 0
    'die_in_side_of_screen'
}

bullets.Sine = bullets.Normal {
    velocity: Vector 0, -200
    sine_movement: amplitude: 10, period: 0.1
}

bullets.Big = Bullet {
    power: 100
    'piercing'
    velocity: Vector 0, -100
    bounding_box: w: 9, h: 9
    draw: =>
        lg.setColor GREEN
        lg.circle 'fill', @position.x + 4.5, @position.y + 4.5, 4
        lg.setColor WHITE
        lg.circle 'line', @position.x + 4.5, @position.y + 4.5, 4
}

bullets.Fraction = Bullet {
    power: 20
    velocity: Vector 0, -300
    acceleration: -7
    'die_on_stop'
    bounding_box: w: 2, h: 2
    draw: =>
        lg.setColor WHITE
        lg.circle 'fill', @position.x + 1, @position.y + 1, 2
}

bullets.Mine = Bullet {
    power: 100
    velocity: Vector 0, 10
    'die_in_bottom_of_screen'
    bounding_box: w: 8, h: 8
    magneting_to_enemy: {radius: 32}
    draw: =>
        lg.setColor WHITE
        lg.circle 'fill', @position.x + 4, @position.y + 4, 3
        lg.setColor RED
        lg.circle 'line', @position.x + 4, @position.y + 4, 3
}

getShootPoint = (entity) -> (entity.position + (entity.shoot_point or Vector.zero))\clone!

weapons = {}

weapons.Weak = Weapon {
    name: 'weak'
    fire_rate: 0.15
    shoot: (world, entity) =>
        world\addEntity bullets.Normal position: getShootPoint(entity)
}

weapons.Side = Weapon {
    name: 'side'
    fire_rate: 0.2
    shoot: (world, entity) =>
        world\addEntity bullets.Side position: getShootPoint(entity)\moveInplace(0, 5)
        world\addEntity bullets.Side position: getShootPoint(entity)\moveInplace(0, 10)
        world\addEntity bullets.Side position: getShootPoint(entity)\moveInplace(0, 5), velocity: Vector 200, 0
        world\addEntity bullets.Side position: getShootPoint(entity)\moveInplace(0, 10), velocity: Vector 200, 0
}

weapons.DoubleAngle = Weapon {
    name: 'double angle'
    fire_rate: 0.1
    shoot: (world, entity) =>
        world\addEntity bullets.Normal position: getShootPoint(entity), velocity: bullets.Normal.velocity\rotated -0.4
        world\addEntity bullets.Normal position: getShootPoint(entity), velocity: bullets.Normal.velocity\rotated 0.4
}

weapons.Sine = Weapon {
    name: 'sine'
    fire_rate: 0.15
    shoot: (world, entity) =>
        world\addEntity bullets.Sine position: getShootPoint(entity)
}

weapons.DoubleSine = Weapon {
    name: 'double sine'
    fire_rate: 0.2
    shoot: (world, entity) =>
        world\addEntity bullets.Sine position: getShootPoint(entity)
        (world\addEntity bullets.Sine position: getShootPoint(entity)).sine_movement.antiphase = true
}

weapons.Big = Weapon {
    name: 'big'
    fire_rate: 0.8
    shoot: (world, entity) =>
        Shake\setShake 4
        world\addEntity bullets.Big position: getShootPoint(entity)\moveInplace -4.5, -4
}

weapons.Shotgun = Weapon {
    name: 'shotgun'
    fire_rate: 1
    shoot: (world, entity) =>
        Shake\setShake 5
        for i=1, 10
            angle = random -0.5, 0.5
            world\addEntity bullets.Fraction position: getShootPoint(entity), velocity: bullets.Fraction.velocity\rotated(angle) * random 0.7, 1
}

weapons.Spread = Weapon {
    name: 'spread'
    fire_rate: 0.05
    shoot: (world, entity) =>
        world\addEntity bullets.Fraction position: getShootPoint(entity), velocity: bullets.Fraction.velocity\rotated(random -0.5, 0.5)
}

weapons.Mines = Weapon {
    name: 'mines'
    fire_rate: 0.8
    shoot: (world, entity) =>
        world\addEntity bullets.Mine position: getShootPoint(entity)\moveInplace -4, 4

}


Player = Entity {
    'player'
    hp: 100
    money: 0
    velocity: Vector 0, 0
    bounding_box: w:16, h:16
    position: Vector SCREEN_W / 2 - 8, SCREEN_H * 0.9
    shoot_point: Vector 8, 0
    speed: 200
    draw: =>
        rotation = 0
        rotation = @velocity.x > 0 and 0.18 or -0.18 if @velocity.x != 0
        scale = @velocity.x != 0 and 0.9 or 1
        lg.setColor WHITE
        lg.draw images.test_ship, @position.x + 8, @position.y + 8, rotation, scale, 1, 8, 8
    'is_handles_input'
    'only_on_screen'
    weapons: {max_size: 3, last_shoot_time: 0, set: {weapons.Mines!}}
}

Enemy = Entity {
    'enemy'
    hp: 100
    position: Vector SCREEN_W / 2, SCREEN_H / 2
    velocity: Vector 0, 100
    bounding_box: w: images.enemy\getWidth!, h: images.enemy\getHeight!
    draw: =>
        -- lg.setColor F.map RED, (k, v) -> return v * (@hp / 100)
        -- lg.rectangle 'fill', @position.x, @position.y, 12, 12
        lg.setColor WHITE
        lg.draw images.enemy, @position.x, @position.y
    'die_in_bottom_of_screen'
    'drops_coins_after_death'
}

Coin = Entity {
    'coin'
    position: getCenterPosition!
    velocity: Vector 0, 0
    standard_velocity: Vector 0, 40
    max_speed: 500
    acceleration: Vector 0, 0
    bounding_box: w:4, h:4
    'die_in_bottom_of_screen'
    'collectable'
    draw: =>
        lg.setColor WHITE
        width = 3 * math.sin 5 * @existing_time
        width = 0.1 if -0.1 < width and width < 0.1
        lg.ellipse 'line', @position.x + 2, @position.y + 2, width, 3
}

Star = Entity {
    'background'
    position: getCenterPosition!
    velocity: Vector 0, 100
    'die_in_bottom_of_screen'
    draw: =>
        lg.setColor WHITE
        lg.circle 'fill', @position.x, @position.y, 1
}

screenVector = (x, y) -> Vector SCREEN_X0 + x, SCREEN_Y0 + y

getRandomTopPosition = -> screenVector (random 20, SCREEN_W - 20), -50

Wave = Entity {
    price: 1
    spawn: (world) =>
        assert false, 'Invalid spawn wave, need spawn function.'
}


waves = {
    Wave {
        price: 1
        spawn: =>
    }
    Wave {
        price: 1
        spawn: (world) => world\addEntity Enemy position: getRandomTopPosition!
    }
    Wave {
        price: 2
        spawn: (world) =>
            world\addEntity Enemy position: screenVector 30, -30
            world\addEntity Enemy position: screenVector SCREEN_W - 30, -30
    }
    Wave {
        price: 3
        spawn: (world) =>
            world\addEntity Enemy position: screenVector(-30 - Enemy.bounding_box.w, -30), velocity: Vector 70, 70
            world\addEntity Enemy position: screenVector(SCREEN_W + 30, -30), velocity: Vector -70, 70
    }
}

EnemySpawner = Entity {
    spawn_energy: 100
    waves: waves
}

systems = {}

systems.listener_init_system = with ECS.system!
    .filter = ECS.requireAny 'spawn_energy', 'weapons'
    .onAdd = (e) =>
        if e.spawn_energy then e.spawn_energy_listener = Talk\listen 'get spawn_energy', -> e.spawn_energy
        if e.weapons then e.weapons_listener = Talk\listen 'get weapons.set', -> Utils.deepCopy e.weapons.set

systems.collider_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'position', 'bounding_box'
    .onAdd = (e) => collider\add e, e.position.x, e.position.y, e.bounding_box.w, e.bounding_box.h
    .onRemove = (e) => collider\remove e
    .process = (e) => collider\update e, e.position.x, e.position.y

systems.enemy_collider_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'bounding_box', 'enemy'
    .process = (e) =>
        for c in *collider\getCollisions e
            if c.other.bullet
                e.hp -= c.other.power
                world\removeEntity c.other

systems.weapon_set_manage_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'weapons'
    .process = (e) =>
        for weapon in *e.weapons.set
            weapon.owner = e
            weapon.world = @world
    .onRemove = (e) => @world\removeEntity weapon for weapon in *e.weapons.set

systems.moving_system = with ECS.processingSystem!
    .onAddToWorld = (world) => world\setSystemIndex @, 1  -- I don't know why, but it fixes shacking on borders.
    .filter = ECS.requireAll 'position', 'velocity'
    .process = (e, dt) =>
        e.position += e.velocity * dt
        e.velocity += e.acceleration * dt if type(e.acceleration) == 'table'  -- If acceleration is a Vector
        e.velocity += e.velocity * e.acceleration * dt if type(e.acceleration) == 'number'
        e.velocity\trimInplace e.max_speed if e.max_speed

systems.enemy_system = with ECS.system!
    .filter = ECS.requireAll 'enemy'

systems.magneting_to_enemy_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'magneting_to_enemy', 'velocity'
    .process = (e, dt) =>
        if not e.magneting_to_enemy.target
            enemies = systems.enemy_system.entities
            nearest_enemy = F.min enemies, (enemy) -> e.position\dist2 enemy.position
            if nearest_enemy and (e.position\dist nearest_enemy.position) <= e.magneting_to_enemy.radius
                e.magneting_to_enemy.target = nearest_enemy
        else
            e.velocity = (e.magneting_to_enemy.target.position - e.position)\normalizeInplace! * 100
            e.magneting_to_enemy.target = nil if e.magneting_to_enemy.target.hp <= 0


systems.only_on_screen_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'only_on_screen', 'position'
    .process = (e, dt) =>
        e.position.x = L.clamp e.position.x, 0, SCREEN_W
        e.position.y = L.clamp e.position.y, 0, SCREEN_H
        if e.bounding_box
            e.position.x = (L.clamp e.position.x + e.bounding_box.w, 0, SCREEN_W) - e.bounding_box.w
            e.position.y = (L.clamp e.position.y + e.bounding_box.h, 0, SCREEN_H) - e.bounding_box.h

systems.die_on_stop_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'die_on_stop', 'velocity'
    .process = (e) => @world\removeEntity e if e.velocity\len2! < .1

systems.sine_moving_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'sine_movement'
    .onAdd = (e) => e.origin_x = e.position.x
    .process = (e, dt) =>
        sign = e.sine_movement.antiphase and -1 or 1
        x_start_offset = e.sine_movement.start_offset or 0
        x_offset = sign * e.sine_movement.amplitude * math.sin(x_start_offset + math.pi * e.existing_time / e.sine_movement.period)
        e.position.x = e.origin_x + x_offset

systems.collectable_moving_system = with ECS.processingSystem!
    .filter = ECS.filter 'player|(collectable&max_speed)'
    .onAdd = (e) => @player = e if e.player
    .process = (e, dt) =>
        if e.collectable
            if @player.weapons.last_shoot_time > 0.3
                e.velocity = (@player\getCenter! - e.position)\normalizeInplace! * e.max_speed
            else
                coin_magnet_radius = 30
                if (@player\getCenter!\dist e.position) < coin_magnet_radius
                    e.velocity = (@player\getCenter! - e.position)\normalizeInplace! * 200
                else
                    e.velocity = e.standard_velocity

addWeapon = (player, weapon) ->
    if #player.weapons.set < player.weapons.max_size
        player.weapons.set[#player.weapons.set + 1] = weapon
    else
        F.pop player.weapons.set 
        F.push player.weapons.set, weapon


systems.collectable_collider_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'player'
    .process = (e) =>
        for c in *collider\getCollisions e
            if c.other.coin
                e.money += 1
                world\removeEntity c.other
                Talk\say 'coin collected'
            if c.other.weapon_pickup
                addWeapon e, c.other.weapon
                world\removeEntity c.other
                Talk\say 'weapon collected'

systems.died_entity_remover_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'hp'
    .process = (e) =>
        if e.enemy and e.hp <= 0
            world\addEntity WeaponPickup position: e.position\clone!, weapon: (L.randomChoice tableToArray weapons)!
            world\removeEntity e
            Shake\setShake 5

systems.drops_coin_after_death = with ECS.processingSystem!
    .filter = ECS.requireAll 'drops_coins_after_death'
    .onRemove = (e) => world\addEntity Coin position: e.position if e.hp <= 0

systems.die_outside_of_screen_system = with ECS.processingSystem!
    .filter = ECS.filter 'position&(die_in_top_of_screen|die_in_bottom_of_screen|die_in_side_of_screen)'
    .process = (e) =>
        if e.die_in_top_of_screen and e.position.y < SCREEN_Y0 or
           e.die_in_bottom_of_screen and e.position.y > SCREEN_H or
           e.die_in_side_of_screen and ((e.position.x < SCREEN_X0) or (e.position.x > SCREEN_X0 + SCREEN_W))
            @world\removeEntity e

systems.input_movement_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'is_handles_input', 'position', 'velocity', 'speed'
    .process = (e, dt) =>
        with e.velocity
            \setZero!
            .x -= e.speed if input\down 'left'
            .x += e.speed if input\down 'right'
            .y -= e.speed if input\down 'up'
            .y += e.speed if input\down 'down'

systems.input_shoot_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'is_handles_input', 'weapons'
    .process = (e, dt) =>
        if input\down 'shoot'
            weapon\down dt for weapon in *e.weapons.set
            e.weapons.last_shoot_time = 0 if e.weapons.last_shoot_time
        e.weapons.last_shoot_time += dt if e.weapons.last_shoot_time

systems.draw_system = with ECS.sortedProcessingSystem!
    .compare = (e1, e2) =>
        if e1.background and not e2.background  -- It is really bad, but working for now.
            return true
        else
            return false
    .is_draw_system = true
    .filter = ECS.requireAll 'draw'
    .process = (e) => e\draw!

systems.update_timer_system = with ECS.processingSystem!
    .filter = ECS.requireAny 'timer', 'existing_time'
    .process = (e, dt) =>
        e.timer\update dt
        e.existing_time += dt

spawnPossibleWave = (world, waves, energy) ->
    available_waves = tableToArray(F.select waves, (_, wave) -> wave.price <= energy)
    chosen_wave = L.randomChoice available_waves
    if chosen_wave
        chosen_wave\spawn world
        return chosen_wave.price
    return 0

systems.enemy_spawner_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'spawn_energy', 'waves'
    .onAdd = (e) =>
        e.add_energy_listener_by_coin = Talk\listen 'coin collected', -> e.spawn_energy += 0.3
        e.time_to_next_wave = 0
        e.time_from_last_pass = 0

        e.timer\every 1, -> @world\addEntity Star position: getRandomTopPosition!, velocity: Vector 0, random 10, 50
    .process = (e, dt) =>
        e.spawn_energy += dt
        e.time_to_next_wave -= dt
        e.time_from_last_pass += dt

        if e.time_to_next_wave <= 0
            e.time_to_next_wave = random 0, 3
            e.spawn_energy -= spawnPossibleWave @world, e.waves, e.spawn_energy

        if e.spawn_energy > 5 and (random 1, 100) < e.time_from_last_pass
            e.spawn_energy -= 5
            e.time_from_last_pass = 0
            e.time_to_next_wave = 0


local fps_graph, mem_graph, entity_graph, collider_graph

intiDebugGraphs = ->
    fps_graph = DebugGraph\new 'fps', 0, 0, 30, 50, 0.2, 'fps', lg.newFont(16)
    mem_graph = DebugGraph\new 'mem', 0, 50, 30, 50, 0.2, 'mem', lg.newFont(16)
    entity_graph = DebugGraph\new 'custom', 0, 100, 30, 50, 0.3, 'ent', lg.newFont(16)

updateDebugGraphs = (dt, world, collider) ->
    fps_graph\update dt
    mem_graph\update dt
    entity_graph\update dt, world\getEntityCount!
    entity_graph.label = 'Entities: ' .. world\getEntityCount! .. '\nCollider: ' .. collider\countItems! .. '\nSpawnEnergy: '
    entity_graph.label ..= L.round(Talk\say'get spawn_energy', .1) if Talk\say 'get spawn_energy'

    if input\pressed 'toggle_debug' then DEBUG = L.toggle DEBUG
    if input\pressed 'collect_garbage' then collectgarbage 'collect'

drawDebugGraphs = ->
    lg.setColor WHITE
    fps_graph\draw!
    mem_graph\draw!
    entity_graph\draw!


drawColliderDebug = (collider) ->
    BumpDebug.draw collider
    lg.setColor DEBUG_RED
    items = collider\getItems!
    lg.rectangle 'line', collider\getRect i for i in *items


drawCurrentWeapons = ->
    cache_font = lg.getFont!
    lg.setFont love.graphics.newFont(16)
    weapons_set = Talk\say 'get weapons.set'
    weapons_names = for n in *weapons_set do
        name = n.name
        name ..= '\n'
        name
    lg.print weapons_names, 10, lg.getHeight! - 60
    lg.setFont cache_font




initInput = ->
    input = with Input!
        \bind 'left', 'left'
        \bind 'right', 'right'
        \bind 'down', 'down'
        \bind 'up', 'up'

        \bind 'a', 'left'
        \bind 'd', 'right'
        \bind 's', 'down'
        \bind 'w', 'up'

        \bind 'space', 'shoot'
        \bind 'z', 'shoot'
        \bind 'x', 'debug_key_1'
        \bind 'c', 'debug_key_2'

        \bind 'f1', 'toggle_debug'
        \bind 'f2', 'collect_garbage'
        \bind 'escape', 'exit'
    return input


love.load = ->
    export world = ECS.world Player! EnemySpawner!
    addAllSystemsTo = (world, systems) -> world\addSystem v for k, v in pairs systems
    addAllSystemsTo world, systems

    export collider = Bump.newWorld SCREEN_W / 5

    export input = initInput!

    export global_timer = Timer!

    intiDebugGraphs!


love.update = (dt) ->
    -- Pie\attach!
    world\update dt, ECS.rejectAny 'is_draw_system'
    -- GameState.update dt

    global_timer\update dt

    Shake\update dt

    updateDebugGraphs dt, world, collider
    if input\pressed 'exit' then love.event.quit!
    -- Pie\detach!

canvas = lg.newCanvas(150, 200)
canvas\setFilter 'nearest'
love.draw = ->
    -- Pie\draw!
    lg.setCanvas canvas
    lg.clear!
    lg.setLineStyle 'rough'

    lg.setBackgroundColor DARK_BLUE

    Shake\apply!

    world\update 0, ECS.requireAll 'is_draw_system'

    drawColliderDebug collider if DEBUG

    lg.setCanvas!
    lg.setColor WHITE
    lg.draw canvas, 0, 0, 0, 4, 4


    drawDebugGraphs! if DEBUG
    drawCurrentWeapons! if SHOW_WEAPONS

-- love.keypressed = (...) -> Pie\keypressed ...
-- love.mousepressed = (...) -> Pie\mousepressed ...

