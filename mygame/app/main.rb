# The Main Game Loop.
#   tick(args) gets called by the lower-level engine for every frame of the game.
#   This makes it easy to program against, because you have absolute control
#   over every single moment.
#
def tick(args)
  if args.inputs.keyboard.key_up.r
    $gtk.reset
    return
  end
  defaults!(args)

  # Break the game if you oops'd the boss.
  if args.state.boss_is_toast
    args.audio.bg = nil

    args.outputs.solids << args.state.stars.map(&:to_h)
    args.outputs.solids << args.state.snow.map(&:to_h)

    args.outputs.sprites << args.state.player
    args.outputs.sprites << args.state.bad_guys
    args.outputs.sprites << args.state.explosions.each(&:tick)

    args.outputs.labels << [1280 / 2, 720 - 50, "You've destroyed the answer...", 3, 1, 232, 93, 117]
    args.outputs.labels << [1280 / 2, 720 - 150, "Press R to try again.", 3, 1, 156, 191, 167]

    return
  end


  # Generate Snow
  args.state.snow << Snow.new(rand(1800) - 200 , 720)

  args.outputs.solids << args.state.stars.each(&:tick).map(&:to_h)
  args.outputs.solids << args.state.snow.each(&:tick).map(&:to_h)

  # Summon a bad guy?
  if args.state.bad_guys.count < 5 && args.state.last_bad_guy_at.elapsed?(0.5.seconds) && args.state.inputs.any?
    args.state.last_bad_guy_at = args.state.tick_count

    x = rand(1000) + 100

    x_positions_in_use = [args.state.player.x, *args.state.bad_guys.map(&:x)]
    if x_positions_in_use.any? {|in_use| (in_use - x).abs < 100 }
      # Don't add a guy here, it's too close to someone else.
      # We'll just try again at the next loop.
    else
      args.state.bad_guys << BadGuy.new(x: x, snacks: args.state.inputs.pop)
    end
  end


  player = args.state.player

  args.outputs.sprites << player.tick

  if args.inputs.keyboard.right
    player.move_right!
  end

  if args.inputs.keyboard.left
    player.move_left!
  end

  if args.inputs.keyboard.space || args.inputs.keyboard.enter || args.inputs.mouse.down
    player.attack!
  end

  # Render bad guys
  args.outputs.sprites << args.state.bad_guys.each(&:tick)

  # Render game text
  current_big_boy = args.state.bad_guys.map(&:calories).max || 0
  if current_big_boy > args.state.biggest_boy_seen
    args.state.biggest_boy_seen = current_big_boy
    args.state.biggest_boy_seen_at = args.tick_count
  end

  if args.state.biggest_boy_seen_at.elapsed_time < 10
    r, g, b = rand(255), rand(255), rand(255)
  else
    r, g, b = 102, 153, 204
  end

  args.outputs.labels << label("Biggest Boy: #{args.state.biggest_boy_seen}", y: 720 - 10, r: r, g: g, b: b)
  args.outputs.labels << label("Elves to check: #{args.state.inputs.count + args.state.bad_guys.count}", r: 102, g: 153, b: 204)

  unless 16.seconds.elapsed?
    args.outputs.labels << label("Find the Big Boy. Get rid of the crumbs...", y: 720 - 90, a: (255 - args.easing.ease(8.seconds, args.state.tick_count, 3.seconds) * 255))
    args.outputs.labels << label("Don't dismiss him before you write the answer.", y: 720 - 120, a: (255 - args.easing.ease(9.seconds, args.state.tick_count, 3.seconds) * 255))
    args.outputs.labels << label("Keep a big boy you see around, in case it's him!", y: 720 - 150, a: (255 - args.easing.ease(11.seconds, args.state.tick_count, 5.seconds) * 255))
  end

  # render explosions
  args.state.explosions.each(&:tick) 
  args.outputs.sprites << args.state.explosions

  # Intro: Fade in from black
  if args.state.tick_count < 8.seconds
    fade_from_black(args, 8.seconds)
  end
end

##
# This runs to set up initial variables and containers for the game to use.
# It makes sure everything is as you expect when you go to use it in the loop
def defaults!(args)
  args.state.player ||= Player.new(args)
  args.state.bad_guys ||= []
  args.state.explosions ||= []
  args.state.wind ||= rand(15) - 10

  # *** Here is the AoC solve, to be used in the game: ***
  args.state.inputs ||= $gtk.read_file("data/input.txt")
    .split("\n\n")
    .map{|elf| elf.split("\n").map(&:to_i)}
    .shuffle
  args.state.max_calories ||= args.state.inputs.map(&:sum).max

  args.state.boss_is_toast ||= false
  args.state.last_bad_guy_at ||= 0
  args.state.biggest_boy_seen ||= 0
  args.state.biggest_boy_seen_at ||= 0

  args.outputs.background_color = [0, 0, 0]
  args.outputs.solids << [0, 0, 1280, 720, 60, 55, 68]
  args.audio.bg ||= {
    input: 'sounds/slow-blues.ogg',
    looping: true,
    gain: 0.1
  }

  if args.state.tick_count == 0

    args.state.stars = (rand * 25 + 15).to_i.times.map {Star.new(rand(1280), rand(720))}
    args.state.snow = (rand * 50 + 20).to_i.times.map {Snow.new(rand(1800) - 200, rand(500) + 300)}

    args.outputs.static_sprites << {
      x: 0, y: 0,
      w: 1280, h: 150,
      path: "sprites/platform.png",
    }

    args.state.bad_guys << BadGuy.new(x: 100, snacks: args.state.inputs.pop)
    args.state.bad_guys << BadGuy.new(x: 1100, snacks: args.state.inputs.pop)
  end
end

##
# A helper to intro the game, extracted because it's not important.
def fade_from_black(args, time_to_fade)
  args.outputs.sprites << {
    path: "sprites/square/black.png",
    x: 0, y: 0,
    w: 1280, h: 720,
    source_x: 10, source_y: 10,
    source_w: 1, source_h: 1,
    a: 255 - args.easing.ease(0, args.state.tick_count, time_to_fade) * 255
  }
end

DEFAULT_LABEL = {
  x: 1280 / 2, y: 720 - 50,
  text: "Override the text with .merge(text: 'my text')",
  size_enum: 3,
  alignment_enum: 1,
  r: 200, g: 200, b: 200
}

# Helper for generating similar looking labels
def label(text, opts={})
  DEFAULT_LABEL.merge(text: text, **opts)
end

class Player
  attr_sprite
  attr_accessor :facing

  SLICE_WIDTH = 40
  SLICE_HEIGHT = 29
  SCALE = 6

  CENTER_X = SLICE_WIDTH * SCALE / 2

  SPEED = 20

  def initialize(args)
    @args = args
    @state = args.state
    @x = 1280 / 2 - (SLICE_WIDTH * SCALE / 2)
    @y = 100 + 20
    @w = SLICE_WIDTH * SCALE
    @h = SLICE_HEIGHT * SCALE
    facing_right!
    @blendmode_enum = 1

    @path = "sprites/ninja.png"

    @source_w = SLICE_WIDTH
    @source_h = SLICE_HEIGHT
  end

  def tick
    # `@hitting = true` will be set during the attack animation
    # dependent on the animation frame.
    # We clear it out each tick before the animation math
    # and check it after the animation.
    @hitting = false

    if @attacking_at
      animate_attacking!
    else
      animate_idle!
    end

    if @hitting
      @args.state.bad_guys.each do |bg|
        if @args.geometry.intersect_rect?(bg, hit_box)
          bg.is_being_hit(@attacking_at)
        end
      end
    end

    self
  end

  def attack!
    @attacking_at = @state.tick_count unless @attacking_at
  end

  # This sets up the zone where strikes occur
  # Because the sprite is not centered, a little extra math happens.
  def hit_box
    shift_x = CENTER_X + (@facing * 30)
    shift_x -= 60 if @facing == -1

    [@x + shift_x, @y + 10, 60 , 100]
  end

  # This chooses correct portion of the sprite map to use
  def animate_idle!
    i = 0.frame_index(3, 10, :loop) # Choose the Y position in the sprite sheet

    i += 2 # offset for borders in sprite sheet
    @source_x = 1
    @source_y = i * SLICE_HEIGHT + i + 1
  end

  # This chooses correct portion of the sprite map to use
  # It also triggers "attacking mode" based on the current animation state.
  def animate_attacking!
    if @attacking_at.elapsed_time == 1
      @args.outputs.sounds << "sounds/swoosh-#{[1,2].sample}.wav"
    end

    i = @attacking_at.frame_index(3, 5)

    # If the animation is over:
    if i.nil?
      @attacking_at = nil
      return
    end

    # The animation is in a "hitting" frame
    @hitting = true if i == 1

    i += 3 # account for borders

    @source_x = 3 * SLICE_WIDTH + 4
    @source_y = i * SLICE_HEIGHT + i + 1
  end

  def flip_horizontally
    @facing == -1
  end

  # The sprite X is not centered...
  def x
    @x + (20 * @facing)
  end
  
  # Movement Stuff:
  LEFT_BOUND = -80
  RIGHT_BOUND = 1280 - (SLICE_WIDTH * SCALE) + 90
  MOVEMENT_RANGE = (LEFT_BOUND...RIGHT_BOUND)

  def move!
    new_x = @x + (SPEED * @facing)
    @x = new_x if MOVEMENT_RANGE.include? new_x
  end

  def move_right!
    facing_right!
    move!
  end

  def move_left!
    facing_left!
    move!
  end

  def facing_right!
    @facing = 1
  end

  def facing_left!
    @facing = -1
  end

  def serialize
    {
      x: x, y: y, w: w, h: h, facing: facing, path: path,
      source_x: source_x, source_y: source_y,
      source_w: source_w, source_h: source_h
    }
  end

  def inspect() = serialize.to_s
  def to_s() = serialize.to_s
end

class BadGuy
  attr_sprite
  attr_reader :calories

  DEFAULT_SCALE = 0.5
  W = 490
  H = 800

  def initialize(x: 100, y: 145,
                 snacks: [9686, 10178, 3375, 9638, 6318, 4978, 5988, 6712])
    @x, @y = x, y
    @args = $gtk.args
    @hp = 1
    @snacks, @calories = snacks, snacks.sum
    @path = "marens-bad-guy-1.png"
    @facing = 1
    @scale = (@calories / @args.state.max_calories) * DEFAULT_SCALE

    @boss = @calories == @args.state.max_calories
    # If it's the Big Boy, give him special treatment:
    if @boss
      # He's a big boy
      @scale = 0.7
      # He is boss, so he's a tough cookie
      @hp = 3
    end

    @w = W * @scale
    @h = H * @scale

    @created_at = @args.state.tick_count
    @last_move_at = @args.state.tick_count
    @last_attacked_by = 0
  end

  def tick
    move! if should_move?
    set_sprite_frame!
    render_calories!

    self
  end

  def serialize
    {x: @x, y: @y, boss: @boss, path: @path}
  end

  def to_s() = serialize.to_s
  alias inspect to_s

  # Set the "facing" of the sprite option
  def flip_horizontally
    @facing == 1
  end  

  def should_move?
    @last_move_at.elapsed?(50) && rand < 0.5
  end

  def move!
    @facing = [-1, 1].sample
    @facing = 1 if @x < 30
    @facing = -1 if @x > (1280 - 100 - @w)
    @x += (@facing * 30)
    @last_move_at = @args.state.tick_count
  end

  def set_sprite_frame!
    i = @created_at.frame_index(3, 30, :loop) + 1
    @path = "sprites/marens-bad-guy-#{i}.png"
  end

  def is_being_hit(attack_id)
    # Only allow one attack per swing
    return if @last_attacked_by == attack_id
    @last_attacked_by = attack_id
    @args.outputs.sounds << "sounds/hit-#{[1,2].sample}.wav"
    @hp -= 1
    explode! if @hp <= 0
  end

  def explode!
    @args.state.explosions << Explosion.new(x: x, y: y, w: w, h: h)

    # If the boss is toast, change game state for the next tick.
    if @boss
      @args.state.boss_is_toast = true
    # Otherwise, this fella goes to the bin.
    else
      @args.state.bad_guys.delete(self)
    end
  end

  # Render this guy's point total above his head.
  def render_calories!
    @args.outputs.labels << label(
      calories,
      x: x + @w / 2,
      y: @y + @h + (@boss? -30 : 30),  # The boss's top is massive, so adding height doesn't work for him.
    )
  end
end

class Explosion
  attr_sprite

  def initialize(x:, y:, w:, h:)
    @x, @y = x, y
    @w, @h = w, h
    @created_at = $args.state.tick_count
  end

  def tick
    i = @created_at.frame_index(7, 3)
    $args.state.explosions.delete(self) if i.nil?
    @path = "sprites/misc/explosion-#{i}.png"

    self
  end
end

class Particle
  attr_reader :x, :y, :w, :h, :r, :g, :b
  def initialize x, y
    @x, @y = x, y
    @h = @w = 2
    @r = @g = @b = 240
    @created_at = $gtk.args.state.tick_count
    after_initialize
  end

  def after_initialize; end

  def to_h
    { x: x, y: y, w: w, h: h, r: r, g: g, b: b }
  end

  alias serialize to_h
  
  def to_s() = serialize.to_s

  alias inspect to_s
end

class Snow < Particle
  def after_initialize
    @speed = rand(4) + 6
  end

  def tick
    $gtk.args.state.snow.delete(self) if @y < 0
    @y -= @speed

    random_shift = rand(6) - 3
    wind_shift = $args.state.wind

    @x += random_shift + wind_shift
    self
  end
end

class Star < Particle
  def after_initialize
    @r -= rand(50)
    @g -= rand(50)
    @b -= rand(50)
    @speed = (rand(12) + 8)
    @x_dir = [-1, 1].sample
    @y_dir = [-1, 1].sample
    @base_w = @base_h = rand(4)
    @w = @base_w *= @x_dir
    @h = @base_h *= @y_dir
  end

  SIZE_SCALE = [1, 2, 3, 2]

  def size_scale
    SIZE_SCALE[@created_at.frame_index(4, @speed, :loop)]
  end

  def tick
    @w = @base_w + size_scale * @x_dir
    @h = @base_h + size_scale * @y_dir
    self
  end
end