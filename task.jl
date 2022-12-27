using HorizonSideRobots
HSR = HorizonSideRobots
HS = HorizonSide



# Structs and Types
mutable struct Coordinates
	x::Int
	y::Int
end
get_axises(coords::Coordinates) = (coords.x, coords.y)

Sides = Union{HorizonSide, NTuple{N, HorizonSide}} where N
get_sides(sides::Sides) = sides isa HorizonSide ? [sides] : sides

@enum Turn begin
	left_turn
	right_turn
end



# Abstract robots
abstract type AbstractRobot end
get_robot(robot::AbstractRobot) = robot.robot

abstract type AbstractDirectedRobot <: AbstractRobot end
get_direction(robot::AbstractDirectedRobot) = robot.direction
set_direction(robot::AbstractDirectedRobot, direction::HorizonSide) = (robot.direction = direction)

abstract type AbstractCoordRobot <: AbstractDirectedRobot end
get_coords(robot::AbstractCoordRobot) = robot.coords



# Robots
mutable struct DirectedRobot <: AbstractDirectedRobot
	DirectedRobot(robot::Robot) = new(robot, Nord)
	DirectedRobot() = new(Robot(animate = true), Nord)

	robot::Robot
	direction::HorizonSide
end

mutable struct CoordRobot <: AbstractCoordRobot
	CoordRobot(robot::Robot) = new(robot, Coordinates(0, 0), Nord)
	CoordRobot() = new(Robot(animate = true), Coordinates(0, 0), Nord)

	robot::Robot
	coords::Coordinates
	direction::HorizonSide
end

mutable struct InsideOutsideRobot <: AbstractCoordRobot
	InsideOutsideRobot(robot::Robot) = new(robot, Coordinates(0, 0), Nord, 0, 0)
	InsideOutsideRobot() = new(Robot(animate = true), Coordinates(0, 0), Nord, 0, 0)

	robot::Robot
	coords::Coordinates
	direction::HorizonSide
	left_turns::Int
	right_turns::Int
end



# Movement
function move!(robot::AbstractRobot, sides::Sides{2})::Nothing
	for side in (sides isa HorizonSide ? [sides] : sides)
		HSR.move!(get_robot(robot), side)
	end
end

function move!(coords::Coordinates, sides::Sides{2})
	for side in get_sides(sides)
		if side == Nord
			coords.y += 1
		elseif side == Sud
			coords.y -= 1
		elseif side == Ost
			coords.x += 1
		elseif side == West
			coords.x -= 1
		end
	end
end

function move!(robot::AbstractCoordRobot, sides::Sides{2})
	invoke(move!, Tuple{AbstractRobot, typeof(sides)}, robot, sides)
	move!(get_coords(robot), sides)
	set_direction(robot, last(get_sides(sides)))
end



# Turn
function turn!(robot::AbstractDirectedRobot, turn::Turn)
	direction = get_direction(robot)

	if turn == left_turn
		set_direction(robot, left(direction))
	elseif turn == right_turn
		set_direction(robot, right(direction))
	end
end

function turn!(robot::InsideOutsideRobot, turn::Turn)
	invoke(turn!, Tuple{supertype(typeof(robot)), typeof(turn)}, robot, turn)

	if turn == left_turn
		robot.left_turns += 1
	elseif turn == right_turn
		robot.right_turns += 1
	end
end



# Bordering
function isborder(robot::AbstractRobot, sides::Sides{2})::Bool
	is_there_border = false
	for side in get_sides(sides)
		is_there_border = is_there_border || HSR.isborder(get_robot(robot), side)
	end
	return is_there_border
end



# Roundabout
function around!(robot::AbstractDirectedRobot, condition::Function)
	while true
		direction = get_direction(robot)

 		if !isborder(robot, direction)
 			move!(robot, direction)
 		end

 		if !isborder(robot, left(direction))
 			turn!(robot, left_turn)
 		elseif isborder(robot, direction)
 			turn!(robot, right_turn)
 		end

		if condition() break end
	end
end

function around!(robot::AbstractDirectedRobot)
	initial_direction = get_direction_by_left_border(robot)
	set_direction(robot, initial_direction)
	putmarker!(robot)

	around!(robot, () -> get_direction(robot) == initial_direction && ismarker(robot))
end

function around!(robot::AbstractCoordRobot)
	initial_x, initial_y = get_axises(get_coords(robot))
	initial_direction = get_direction_by_left_border(robot)
	set_direction(robot, initial_direction)
	
	function condition()
		x, y = get_axises(get_coords(robot))

		return get_direction(robot) == initial_direction && initial_x == x && initial_y == y
	end

	around!(robot, condition)
end

function around!(robot::InsideOutsideRobot)
	robot.left_turns = 0
	robot.right_turns = 0

	invoke(around!, Tuple{supertype(typeof(robot))}, robot)

	if robot.left_turns < robot.right_turns
		println("Robot is inside of labirinth")
	else
		println("Robot is outside of labirinth")
	end
end



# Overloads
putmarker!(robot::AbstractRobot) = HSR.putmarker!(get_robot(robot))
ismarker(robot::AbstractRobot) = HSR.ismarker(get_robot(robot))
temperature(robot::AbstractRobot) = HSR.temperature(get_robot(robot))



# Utils
function get_direction_by_left_border(robot::AbstractDirectedRobot)::HorizonSide
	direction = get_direction(robot)

	if isborder(robot, direction)
		direction = right(direction)
	elseif isborder(robot, left(direction))
		direction = direction
	elseif isborder(robot, right(direction))
		direction = inverse(direction)
	elseif isborder(robot, inverse(direction))
		direction = left(direction)
	end

	return direction
end

function right(side::HorizonSide)
	if side == Nord
		return Ost
	elseif side == Sud
		return West
	elseif side == Ost
		return Sud
	elseif side == West
		return Nord
	end
end

function left(side::HorizonSide)
	if side == Nord
		return West
	elseif side == Sud
		return Ost
	elseif side == Ost
		return Nord
	elseif side == West
		return Sud
	end
end

function inverse(side::HorizonSide)
	if side == Nord
		return Sud
	elseif side == Sud
		return Nord
	elseif side == Ost
		return West
	elseif side == West
		return Ost
	end
end



# Initial data
robot = InsideOutsideRobot(Robot("untitled.sit", animate = true))

