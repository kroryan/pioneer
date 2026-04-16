-- Copyright © 2025 Hypernoot, license: CC-BY-SA 4.0 International

-- Remove these entries from data/systems/partial/02_local_stars.json
--    {"name": "Alpha Centauri", "stars": ["STAR_G", "STAR_K"], "otherNames": ["Bungula", "Toliman", "α Centauri", "Rigil Kentaurus", "Gliese 551", "Gliese 559", "FK5 538", "HIP 70890"], "sector": [-1, 0, -1], "pos": [6.624, 1.632, 4.16]},
--    {"name": "Proxima Centauri", "stars": ["STAR_M"], "sector": [-1, 0, -1], "pos": [6.824, 1.528, 4.248]},

local s = CustomSystem:new('Alpha Centauri', { 'STAR_G', "STAR_K", "STAR_M" })
	:govtype('EARTHDEMOC')
	:short_desc('Closest star system to Sol.')
	:long_desc([[Alpha Centauri is the closest stellar system from Sol. First robotic expeditions visited the system back in 2261 but they did not find there any planet suitable for massive colonisation. Nevertheless, the climatic conditions of some bodies are sufficient to build human settlements with relatively low effort. Some colonies were set up in the Proxima Centauri subsystem between 2295 and 2311, with the hope that the planet terraformation may start later, when enough funds are freed. However, that has not happened for centuries, mostly because more profitable planets were found in other stellar systems. The profit of the colonies barely sufficed for their own maintenance, so they developed very slowly.

The system gained its importance in 2722, when the Solar Federation started building there military bases, in order to provide a threat to the Free Republic. During the War of Hope (2723-2725), it served as an important source of ammunition for the Solar Federation. Since then, it serves as an important military base for the Solar Federation, and as a potential threat to the Commonwealth of Independent Worlds.]])

local AlphaCen = CustomSystemBody:new("Alpha Centauri", 'GRAVPOINT')
	:radius(f(0,10000))
	:mass(f(9940,10000))

-- Rigil Kentaurus subsystem

local AlphaCenA = CustomSystemBody:new("Rigil Kentaurus", 'STAR_G')
	:radius(f(12175,10000))
	:mass(f(10788,10000))
	:seed(31647)
	:temp(5804)
	:semi_major_axis(f(107638,10000))
	:eccentricity(f(51947,100000))
	:orbital_offset(fixed.deg2rad(f(-88,1)))

local AlphaCenAb = CustomSystemBody:new("Šemík", 'PLANET_GAS_GIANT') -- candidate known as Rigil Kentaurus b
	:radius(f(11762,1000))
	:mass(f(142,1))
	:seed(132846142)
	:temp(225)
	:semi_major_axis(f(195,100))
	:eccentricity(f(442,1000))
	:rotation_period(f(11243,24000))
	:axial_tilt(fixed.deg2rad(f(13,10000)))
	:orbital_offset(fixed.deg2rad(f(-2,1)))
	:life(f(0,10000))
	:rings(true)

local AlphaCenASystem = {
	CustomSystemBody:new('Čtvrtsmršť', 'PLANET_ASTEROID')
		:seed(26241)
		:radius(f(332,100000))
		:mass(f(1252,100000000000))
		:temp(1288)
		:semi_major_axis(f(341,1000))
		:eccentricity(f(3126,10000))
		:inclination(math.deg2rad(1.9642))
		:rotation_period(f(18421,1000))
		:rings(false),
	--[[AlphaCenAb, {
		CustomSystemBody:new('Horymír', 'PLANET_TERRESTRIAL')
			:seed(21587)
			:radius(f(82,1000))
			:mass(f(22,100000))
			:temp(225)
			:semi_major_axis(f(63,10000))
			:eccentricity(f(326,10000))
			:inclination(math.deg2rad(1.9642))
			:atmos_density(f(84,1000))
			:atmos_oxidizing(f(2,10))
			:rotation_period(f(18421,1000))
			:rings(false),
		{
			CustomSystemBody:new('Vyšehrad', 'STARPORT_SURFACE')
				:latitude(math.deg2rad(56))
				:longitude(math.deg2rad(24)),
			CustomSystemBody:new('Fort Delta', 'STARPORT_ORBITAL')
				:semi_major_axis(f(52,1000000))
				:eccentricity(f(28,1000))
				:rotation_period(f(44,24)),
		},
		CustomSystemBody:new('Fort Alfa', 'STARPORT_ORBITAL')
			:semi_major_axis(f(52,1000))
			:eccentricity(f(28,1000))
			:rotation_period(f(44,24)),
	}--]]  --This doesn't work due to a bug
	CustomSystemBody:new('Fort Alfa', 'STARPORT_ORBITAL')
		:semi_major_axis(f(341,1000))
		:eccentricity(f(4428,10000))
		:rotation_period(f(44,24))
		:inclination(math.deg2rad(31.9833)),
}

-- Toliman subsystem

local AlphaCenB = CustomSystemBody:new("Toliman", 'STAR_K')
	:radius(f(8591,10000))
	:mass(f(9092,10000))
	:seed(31647)
	:temp(5207)
	:semi_major_axis(f(12534,1000))
	:eccentricity(f(51947,100000))
	:orbital_offset(fixed.deg2rad(f(92,1)))

local AlphaCenBb = CustomSystemBody:new("Ixion", 'PLANET_TERRESTRIAL') -- disproven discovery, known as Alpha Centauri Bb
	:radius(f(862,1000))
	:mass(f(442,1000))
	:seed(962465125)
	:temp(1426)
	:volcanicity(f(73,100))
	:semi_major_axis(f(412,10000))
	:eccentricity(f(134,1000))
	:rotation_period(f(2136,1000))
	:axial_tilt(fixed.deg2rad(f(621,10000)))
	:life(f(0,10000))
	:rings(false)

local AlphaCenBc = CustomSystemBody:new("Hellgoland", 'PLANET_TERRESTRIAL') -- candidate known as Alpha Centauri Bc
	:radius(f(921,1000))
	:mass(f(442,1000))
	:seed(912245125)
	:temp(577)
	:volcanicity(f(18,100))
	:semi_major_axis(f(1018,10000))
	:eccentricity(f(122,1000))
	:rotation_period(f(8324,1000))
	:axial_tilt(fixed.deg2rad(f(621,10000)))
	:life(f(0,10000))
	:rings(false)

local AlphaCenBSystem = {
	AlphaCenBb,
	AlphaCenBc,
	{
		CustomSystemBody:new('Cryptominers\' Paradise', 'STARPORT_SURFACE')
			:latitude(math.deg2rad(-88))
			:longitude(math.deg2rad(-73)),
		CustomSystemBody:new('Fort Oscar', 'STARPORT_ORBITAL')
			:semi_major_axis(f(636,1000000))
			:eccentricity(f(412,1000))
			:rotation_period(f(14,24)),
	},
	CustomSystemBody:new('Fort Bravo', 'STARPORT_ORBITAL')
		:semi_major_axis(f(1901,10000))
		:eccentricity(f(128,1000))
		:rotation_period(f(52,24)),
}

-- Proxima Centauri subsystem

local AlphaCenC = CustomSystemBody:new("Proxima Centauri", 'STAR_M')
	:radius(f(1542,10000))
	:mass(f(1221,10000))
	:seed(9467214)
	:temp(2992)
	:semi_major_axis(f(8700,1))
	:eccentricity(f(5,10))
	:orbital_offset(fixed.deg2rad(f(486451,10000)))
	:orbital_phase_at_start(fixed.deg2rad(f(161,1)))

local AlphaCenCd = CustomSystemBody:new("Arion", 'PLANET_TERRESTRIAL') -- discovery knonw as Proxima Centauri d
	:radius(f(818,1000))
	:mass(f(272,1000))
	:seed(5157472)
	:temp(360)
	:semi_major_axis(f(288,10000))
	:eccentricity(f(19,1000))
	:rotation_period(f(98451,24000))
	:axial_tilt(fixed.deg2rad(f(10,10000)))
	:life(f(0,10000))
	:rings(false)

local AlphaCenCb = CustomSystemBody:new("Rhaebus", 'PLANET_TERRESTRIAL') -- discovery known as Proxima Centauri b
	:radius(f(1224,1000))
	:mass(f(1055,1000))
	:seed(1202321242)
	:temp(234)
	:semi_major_axis(f(485,10000))
	:eccentricity(f(24,1000))
	:rotation_period(f(31642,24000))
	:axial_tilt(fixed.deg2rad(f(104,10000)))
	:life(f(0,10000))
	:rings(false)

local AlphaCenCc = CustomSystemBody:new("Hippocampus", 'PLANET_GAS_GIANT') -- candidate known as Proxima Centauri c
	:radius(f(3421,1000))
	:mass(f(7213,1000))
	:seed(96421472)
	:temp(39)
	:semi_major_axis(f(1489,1000))
	:eccentricity(f(19,1000))
	:rotation_period(f(18421,24000))
	:axial_tilt(fixed.deg2rad(f(32,10000)))
	:life(f(0,10000))
	:rings(f(1524,1000), f(6401,1000), {0.531, 0.436, 0.442, 0.748})

local AlphaCenCSystem = {
	AlphaCenCd, {
		CustomSystemBody:new('Nerdopolis', 'STARPORT_SURFACE')
			:latitude(math.deg2rad(64))
			:longitude(math.deg2rad(21)),
		CustomSystemBody:new('SolFed Drone Factory', 'STARPORT_SURFACE')
			:latitude(math.deg2rad(-11))
			:longitude(math.deg2rad(147)),
		CustomSystemBody:new('Fort Foxtrott', 'STARPORT_ORBITAL')
			:semi_major_axis(f(1232,1000000))
			:eccentricity(f(124,1000))
			:rotation_period(f(19,24)),
	},
	AlphaCenCb, {
		CustomSystemBody:new('Hopson\'s Colony', 'STARPORT_SURFACE')
			:latitude(math.deg2rad(12))
			:longitude(math.deg2rad(64)),
		CustomSystemBody:new('Kentaur City', 'STARPORT_SURFACE')
			:latitude(math.deg2rad(-16))
			:longitude(math.deg2rad(-31)),
		CustomSystemBody:new('SolFed Refinery', 'STARPORT_SURFACE')
			:latitude(math.deg2rad(38))
			:longitude(math.deg2rad(118)),
		CustomSystemBody:new('Fort Golf', 'STARPORT_ORBITAL')
			:semi_major_axis(f(421,1000000))
			:eccentricity(f(32,1000))
			:rotation_period(f(18,24)),
		CustomSystemBody:new('Fort Hotel', 'STARPORT_ORBITAL')
			:semi_major_axis(f(1462,1000000))
			:eccentricity(f(38,1000))
			:rotation_period(f(18,24)),
	},
	CustomSystemBody:new('Fort Charlie', 'STARPORT_ORBITAL')
		:semi_major_axis(f(842,10000))
		:eccentricity(f(12,1000))
		:rotation_period(f(36,24)),
	CustomSystemBody:new('Scvrk', 'PLANET_ASTEROID')
		:seed(6121423)
		:radius(f(946,100000))
		:mass(f(20412,100000000000))
		:temp(92)
		:semi_major_axis(f(1248,10000))
		:eccentricity(f(174,10000))
		:inclination(math.deg2rad(1.0241))
		:rotation_period(f(9246,1000))
		:rings(false),	
	CustomSystemBody:new('Trud', 'PLANET_TERRESTRIAL')
		:seed(215878452)
		:radius(f(172,1000))
		:mass(f(192,100000))
		:temp(52)
		:semi_major_axis(f(3639,10000))
		:eccentricity(f(1126,10000))
		:inclination(math.deg2rad(3.1242))
		:rotation_period(f(6247,1000))
		:rings(false),
	AlphaCenCc, {
		CustomSystemBody:new('Uwu', 'PLANET_ASTEROID')
			:seed(945123)
			:radius(f(798,100000))
			:mass(f(12174,100000000000))
			:temp(39)
			:semi_major_axis(f(112,10000))
			:eccentricity(f(174,10000))
			:inclination(math.deg2rad(1.0241))
			:rotation_period(f(9642,1000))
			:ice_cover(f(4,10))
			:rings(false),	
		CustomSystemBody:new('Meow', 'PLANET_ASTEROID')
			:seed(468132123)
			:radius(f(674,100000))
			:mass(f(9229,100000000000))
			:temp(39)
			:semi_major_axis(f(152,10000))
			:eccentricity(f(154,10000))
			:inclination(math.deg2rad(2.015))
			:rotation_period(f(24751,1000))
			:ice_cover(f(7,10))
			:rings(false),	
		CustomSystemBody:new('Nyaa', 'PLANET_ASTEROID')
			:seed(867421)
			:radius(f(942,100000))
			:mass(f(20423,100000000000))
			:temp(39)
			:semi_major_axis(f(238,10000))
			:eccentricity(f(363,10000))
			:inclination(math.deg2rad(0.4214))
			:rotation_period(f(12417,1000))
			:ice_cover(f(8,10))
			:rings(false),	
		CustomSystemBody:new('Noot', 'PLANET_ASTEROID')
			:seed(89456123)
			:radius(f(363,100000))
			:mass(f(1088,100000000000))
			:temp(39)
			:semi_major_axis(f(363,10000))
			:eccentricity(f(942,10000))
			:inclination(math.deg2rad(1.5425))
			:rotation_period(f(11641,1000))
			:ice_cover(f(10,10))
			:rings(false),	
		CustomSystemBody:new('Fort Sierra', 'STARPORT_ORBITAL')
			:semi_major_axis(f(522,10000))
			:eccentricity(f(18,1000))
			:rotation_period(f(14,24)),
	},
	CustomSystemBody:new('Brekeq', 'PLANET_TERRESTRIAL')
		:seed(28421421)
		:radius(f(184,1000))
		:mass(f(205,100000))
		:temp(32)
		:semi_major_axis(f(25842,10000))
		:eccentricity(f(826,10000))
		:inclination(math.deg2rad(0.4231))
		:rotation_period(f(7424,1000))
		:rings(false),
	CustomSystemBody:new('Fort Yankee', 'STARPORT_ORBITAL')
		:semi_major_axis(f(38451,10000))
		:eccentricity(f(94,1000))
		:rotation_period(f(14,24)),
	CustomSystemBody:new('Fort Zulu', 'STARPORT_ORBITAL')
		:semi_major_axis(f(56246,10000))
		:eccentricity(f(122,1000))
		:rotation_period(f(14,24)),
}

s:bodies(AlphaCen,{
		AlphaCenA, AlphaCenASystem,
		AlphaCenB, AlphaCenBSystem,
		CustomSystemBody:new('Turf', 'PLANET_ASTEROID')
			:seed(22416)
			:radius(f(832,100000))
			:mass(f(12252,100000000000))
			:temp(6)
			:semi_major_axis(f(122321,1000))
			:eccentricity(f(2641,10000))
			:inclination(math.deg2rad(1.214))
			:rotation_period(f(11428,1000))
			:rings(false),
		{
			CustomSystemBody:new('Fort Echo', 'STARPORT_SURFACE')
				:latitude(math.deg2rad(0))
				:longitude(math.deg2rad(31))
		},
		CustomSystemBody:new('Cvrnk', 'PLANET_ASTEROID')
			:seed(22416)
			:radius(f(432,100000))
			:mass(f(4869,100000000000))
			:temp(4)
			:semi_major_axis(f(275431,1000))
			:eccentricity(f(2641,10000))
			:inclination(math.deg2rad(6.964))
			:rotation_period(f(13296,1000))
			:rings(false),
		{
			CustomSystemBody:new('Gobble', 'PLANET_ASTEROID')
				:seed(22416)
				:radius(f(188,100000))
				:mass(f(649,100000000000))
				:temp(4)
				:semi_major_axis(f(4216,100000000))
				:eccentricity(f(6214,10000))
				:inclination(math.deg2rad(16.214))
				:rotation_period(f(43226,1000))
				:rings(false),
		},
		AlphaCenC, AlphaCenCSystem
	}
)

s:add_to_sector(-1,0,-1,v(0.6624,0.1632,0.416))
