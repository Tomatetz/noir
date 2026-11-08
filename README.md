# Water Exchange

A playable Godot prototype inspired by *Space Rangers 2*. In a near future reshaped by drought, water, electricity, and computing power drive the economy. You run a caravan between settlements while a corporate AI project threatens the region's water supply.

## Gameplay

- Trade supplies and take delivery contracts between settlements, each with its own prices and security risks.
- Plan routes and fight turn-based vehicle battles. Move to the next checkpoint or hold your position to fire without moving.
- Compare and buy vehicles in the showroom, then outfit and repair them in the garage. Chassis differ in speed, cargo capacity, and weapon mounts.

The current in-game interface is in Russian.

## Installation

### 1. Install Godot

Install the standard edition of [Godot 4.7](https://godotengine.org/download/) for your operating system. The prototype uses GDScript and requires no additional dependencies.

### 2. Clone the repository

```sh
git clone https://github.com/Tomatetz/noir.git
cd noir
```

If you use SSH with GitHub, you can clone with `git clone git@github.com:Tomatetz/noir.git` instead.

### 3. Run the game

In the Godot Project Manager, choose **Import**, select `project.godot`, and open the project. Press **F5** or click **Run Project** to start the main scene, `res://scenes/Main.tscn`.

If `godot` is available on your command line, you can also run the game from the repository directory:
```sh
godot --path .
```

For a quick script check without opening a window:

```sh
godot --headless --path . --check-only --script res://scripts/MapPanel.gd
```

