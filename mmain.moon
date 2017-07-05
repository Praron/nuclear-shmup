require 'libs/autobatch'
F = require 'libs/moses'
L = require 'libs/lume'
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

Utils = require 'libs/utils'

setmetatable _G, __index: require('libs/cargo').init
    dir: 'assets'
    processors:
        ['images/']: (image, filename) ->
            image\setFilter 'nearest'

{graphics: lg, math: lm} = love

export DEBUG = true

export SCREEN_W = 150
export SCREEN_H = 200

WHITE = {255, 255, 255}
DEBUG_RED = {255, 150, 150}
GREEN = {106, 190, 48}
RED = {172, 50, 50}
DARK_BLUE = {34, 32, 52}


Entity = (components) ->
    for i = 1, #components
        component = components[i]
        components[component] = true
        components[i] = nil

    components.new = (t = {}) =>
        entity = Utils.deepCopy @
        entity[k] = v for k, v in pairs t
        return entity
    setmetatable components, __call: (t) => @\new t

    components.timer = Timer!
    components.existing_time = 0

    return components

Weapon = Entity {
    'weapon'
    shoot_time: 0
    down: (dt) =>
        @shoot_time += dt
        if @shoot_time >= @fire_rate
            @shoot @world, @owner
            @shoot_time -= @fire_rate
}

Bullet = Entity {
    'bullet'
    'die_in_top_of_screen'
}

NormalBullet = Bullet {
    power: 20
    position: Vector SCREEN_W / 2, SCREEN_H / 2
    velocity: Vector 0, 0
    bounding_box: w:3, h:3
    draw: =>
        lg.setColor WHITE
        -- lg.circle 'fill', @position.x, @position.y, 8
        lg.circle 'fill', @position.x, @position.y, 2
}

SineBullet = NormalBullet {
    sine_movement: amplitude: 10, period: 0.1
}

getShootPoint = (entity) -> (entity.position + (entity.shoot_point or Vector.zero))\clone!

WeakWeapon = Weapon {
    fire_rate: 0.15
    shoot: (world, entity) =>
        world\addEntity NormalBullet position: getShootPoint(entity), velocity: Vector 0, -300
}

DoubleAngleWeapon = Weapon {
    fire_rate: 0.1
    shoot: (world, entity) =>
        world\addEntity NormalBullet position: getShootPoint(entity), velocity: (Vector 0, -300)\rotateInplace -0.4
        world\addEntity NormalBullet position: getShootPoint(entity), velocity: (Vector 0, -300)\rotateInplace 0.4
}

SineWeapon = Weapon {
    fire_rate: 0.15
    shoot: (world, entity) =>
        world\addEntity SineBullet position: getShootPoint(entity), velocity: Vector 0, -200
}

DoubleSineWeapon = Weapon {
    fire_rate: 0.2
    shoot: (world, entity) =>
        world\addEntity SineBullet position: getShootPoint(entity), velocity: Vector 0, -200
        (world\addEntity SineBullet position: getShootPoint(entity), velocity: Vector 0, -200).sine_movement.antiphase = true
}


Player = Entity {
    hp: 100
    money: 0
    velocity: Vector 0, 0
    bounding_box: w:16, h:16
    position: Vector SCREEN_W / 2 - 8, SCREEN_H * 0.9
    shoot_point: Vector 8, 0
    speed: 200
    draw: =>
        -- lg.setColor GREEN
        -- lg.polygon 'fill', @position.x, @position.y - 30,
        --                    @position.x + 20, @position.y + 30,
        --                    @position.x - 20, @position.y + 30
        -- lg.draw images.test_ship, @position.x - images.test_ship\getWidth! - 15, @position.y, 0, 4, 4
        lg.draw images.test_ship, @position.x, @position.y
    'is_handles_input'
    'only_on_screen'
    'player'
    -- weapon_set: {WeakWeapon!, DoubleAngleWeapon!}
    weapon_set: {SineWeapon!}
    last_shoot_time: 0
}

Enemy = Entity {
    hp: 100
    position: Vector SCREEN_W / 2, SCREEN_H / 2
    velocity: Vector 0, 100
    bounding_box: w:12, h:12
    draw: =>
        lg.setColor F.map RED, (k, v) -> return v * (@hp / 100)
        lg.rectangle 'fill', @position.x, @position.y, 12, 12
    'enemy'
    'die_in_bottom_of_screen'
    'drops_coins_after_death'
}

getCenterPosition = -> Vector SCREEN_W / 2, SCREEN_H / 2

Coin = Entity {
    position: getCenterPosition!
    velocity: Vector 0, 0
    max_speed: 500
    acceleration: Vector 0, 0
    bounding_box: w:4, h:4
    'collectable'
    'coin'
    draw: =>
        lg.setColor WHITE
        -- lg.circle 'line', @position.x + 2, @position.y + 2, 3
        width = 3 * math.sin 5 * @existing_time
        width = 0.1 if -0.1 < width and width < 0.1
        lg.ellipse 'line', @position.x + 2, @position.y + 2, width, 3
}

EnemySpawner = Entity {
    spawn_energy: 0
}

getRandomTopPosition = -> Vector (random 20, SCREEN_W - 20), -50

systems = {}

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
    .filter = ECS.requireAll 'weapon_set'
    .process = (e) =>
        for weapon in *e.weapon_set
            weapon.owner = e
            weapon.world = @world
            @world\addEntity weapon
    .onRemove = (e) => @world\removeEntity weapon for weapon in *e.weapon_set

systems.collectable_collider_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'player'
    .process = (e) =>
        for c in *collider\getCollisions e
            if c.other.coin
                e.money += 1
                world\removeEntity c.other

systems.only_on_screen_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'only_on_screen', 'position'
    .process = (e, dt) =>
        e.position.x = L.clamp e.position.x, 0, SCREEN_W
        e.position.y = L.clamp e.position.y, 0, SCREEN_H
        if e.bounding_box
            e.position.x = (L.clamp e.position.x + e.bounding_box.w, 0, SCREEN_W) - e.bounding_box.w
            e.position.y = (L.clamp e.position.y + e.bounding_box.h, 0, SCREEN_H) - e.bounding_box.h

systems.moving_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'position', 'velocity'
    .process = (e, dt) =>
        e.position += e.velocity * dt
        e.velocity += e.acceleration if e.acceleration
        e.velocity\trimInplace e.max_speed if e.max_speed

systems.sine_moving_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'sine_movement'
    .onAdd = (e) => e.origin_x = e.position.x
    .process = (e, dt) =>
        sign = e.sine_movement.antiphase and -1 or 1
        x_start_offset = e.sine_movement.start_offset or 0
        x_offset = sign * e.sine_movement.amplitude * math.sin(x_start_offset + math.pi * e.existing_time / e.sine_movement.period)
        e.position.x = e.origin_x + x_offset

systems.collectable_moving_system = with ECS.processingSystem!
    .filter = ECS.requireAny 'collectable', 'player'
    .onAdd = (e) => @player = e if e.player
    .process = (e, dt) =>
        if not e.player
            if @player.last_shoot_time > 0.3
                e.velocity = (@player.position - e.position)\normalizeInplace! * e.max_speed
            else
                coin_magnet_radius = 30
                if (@player.position\dist e.position) < coin_magnet_radius
                    e.velocity = (@player.position - e.position)\normalizeInplace! * 300
                else
                    e.velocity\setZero!

systems.died_entity_remover_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'hp'
    .process = (e) => world\removeEntity e if e.hp <= 0

systems.drops_coin_after_death = with ECS.processingSystem!
    .filter = ECS.requireAll 'drops_coins_after_death'
    .onRemove = (e) => world\addEntity Coin position: e.position if e.hp <= 0

systems.die_outside_of_screen_system = with ECS.processingSystem!
    .filter = ECS.filter 'position&(die_in_top_of_screen|die_in_bottom_of_screen)'
    .process = (e) =>
        if e.die_in_top_of_screen and e.position.y < 0 or
           e.die_in_bottom_of_screen and e.position.y > SCREEN_H
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
    .filter = ECS.requireAll 'is_handles_input', 'weapon_set'
    .process = (e, dt) =>
        if input\down 'shoot'
            weapon\down dt for weapon in *e.weapon_set
            e.last_shoot_time = 0 if e.last_shoot_time
        e.last_shoot_time += dt if e.last_shoot_time

        if input\pressed 'debug_key_1' then e.weapon_set[#e.weapon_set + 1] = SineWeapon!
        if input\pressed 'debug_key_2' then e.weapon_set[#e.weapon_set + 1] = DoubleSineWeapon!

systems.draw_system = with ECS.processingSystem!
    .is_draw_system = true
    .filter = ECS.requireAll 'draw'
    .process = (e) => e\draw!

systems.update_timer_system = with ECS.processingSystem!
    .filter = ECS.requireAny 'timer', 'existing_time'
    .process = (e, dt) =>
        e.timer\update dt
        e.existing_time += dt

systems.enemy_spawner_system = with ECS.processingSystem!
    .filter = ECS.requireAll 'spawn_energy'
    .process = (e, dt) =>
        e.spawn_energy += dt
        if e.spawn_energy > 1 and random! < 1
            e.spawn_energy -= 1
            world\addEntity Enemy position: getRandomTopPosition!


local fps_graph, mem_graph, entity_graph, collider_graph

intiDebugGraphs = ->
    fps_graph = DebugGraph\new 'fps', 0, 0, 30, 50, 0.2, 'fps', lg.newFont(16)
    mem_graph = DebugGraph\new 'mem', 0, 50, 30, 50, 0.2, 'mem', lg.newFont(16)
    entity_graph = DebugGraph\new 'custom', 0, 100, 30, 50, 0.3, 'ent', lg.newFont(16)

updateDebugGraphs = (dt, world, collider) ->
    fps_graph\update dt
    mem_graph\update dt
    entity_graph\update dt, world\getEntityCount!
    entity_graph.label = 'Entities: ' .. world\getEntityCount! .. '\nCollider: ' .. collider\countItems!

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
    export world = ECS.world Player!, EnemySpawner!
    addAllSystemsTo = (world, systems) -> world\addSystem v for k, v in pairs systems
    addAllSystemsTo world, systems

    export collider = Bump.newWorld SCREEN_W / 5

    export input = initInput!

    export global_timer = Timer!

    intiDebugGraphs!


love.update = (dt) ->
    world\update dt, ECS.rejectAny 'is_draw_system'
    -- GameState.update dt

    global_timer\update dt

    updateDebugGraphs dt, world, collider
    if input\pressed 'exit' then love.event.quit!


canvas = lg.newCanvas(150, 200)
canvas\setFilter 'nearest'
love.draw = ->
    lg.setCanvas canvas
    lg.clear!
    lg.setLineStyle 'rough'
    -- lg.setColor WHITE

    lg.setBackgroundColor DARK_BLUE

    world\update 0, ECS.requireAll 'is_draw_system'

    drawColliderDebug collider if DEBUG

    lg.setCanvas!
    lg.setColor WHITE
    lg.draw canvas, 0, 0, 0, 4, 4

    drawDebugGraphs! if DEBUG
