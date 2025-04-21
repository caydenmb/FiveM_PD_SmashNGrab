Config = {}

-- Authorized Jobs
Config.AuthorizedJobs = {
    'police',
    'sheriff'
}

-- Maximum distance between officer and target to allow action.
Config.MaxTargetDistance = 5.0

-- Map vehicle seat indexes → window indexes for SmashVehicleWindow()
-- Seat -1 = driver, 0 = front passenger, 1 = rear left, 2 = rear right
Config.WindowIndex = {
    [-1] = 0,
     [0] = 1,
     [1] = 2,
     [2] = 3
}

-- Friendly names for seats (used in notifications)
Config.SeatNames = {
    [-1] = "driver-side front",
     [0] = "passenger-side front",
     [1] = "driver-side rear",
     [2] = "passenger-side rear"
}

-- Place the ped once they exit the vehicle.
-- Vector3: X = left/right, Y = forward/back, Z = up/down
Config.ExitOffsets = {
    [-1] = vector3(-1.5,  0.2, 0.0),
     [0] = vector3( 1.5,  0.2, 0.0),
     [1] = vector3(-1.5, -0.5, 0.0),
     [2] = vector3( 1.5, -0.5, 0.0)
}
