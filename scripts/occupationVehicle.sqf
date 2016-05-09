if (!isServer) exitWith {};

_logDetail = format['[OCCUPATION:Vehicle] Started'];
[_logDetail] call SC_fnc_log;

// set the default side for bandit AI
_side               = "bandit"; 

if(SC_occupyVehicleSurvivors) then 
{   
    if(!isNil "DMS_Enable_RankChange") then { DMS_Enable_RankChange = true;  };
};

// more than _scaleAI players on the server and the max AI count drops per additional player
_currentPlayerCount = count playableUnits;
_maxAIcount 		= SC_maxAIcount;

if(_currentPlayerCount > SC_scaleAI) then 
{
	_maxAIcount = _maxAIcount - (_currentPlayerCount - SC_scaleAI) ;
};

// Don't spawn additional AI if the server fps is below _minFPS
if(diag_fps < SC_minFPS) exitWith 
{ 
    _logDetail = format ["[OCCUPATION:Vehicle]:: Held off spawning more AI as the server FPS is only %1",diag_fps]; 
    [_logDetail] call SC_fnc_log; 
};

_aiActive = {alive _x && (side _x == SC_BanditSide OR side _x == SC_SurvivorSide) && !SC_occupyVehicleIgnoreCount} count allUnits;
if(_aiActive > _maxAIcount) exitWith 
{ 
    _logDetail = format ["[OCCUPATION:Vehicle]:: %1 active AI, so not spawning AI this time",_aiActive]; 
    [_logDetail] call SC_fnc_log; 
};

if(SC_liveVehicles >= SC_maxNumberofVehicles) exitWith 
{
    if(SC_extendedLogging) then 
    { 
        _logDetail = format['[OCCUPATION:Vehicle] End check %1 currently active (max %2) @ %3',SC_liveVehicles,SC_maxNumberofVehicles,time]; 
        [_logDetail] call SC_fnc_log;
    };   
};

_vehiclesToSpawn = (SC_maxNumberofVehicles - SC_liveVehicles);

if(SC_extendedLogging) then 
{ 
	if(_vehiclesToSpawn > 0) then 
	{ 
		_logDetail = format['[OCCUPATION:Vehicle] Started %2 currently active (max %3) spawning %1 extra vehicle(s) @ %4',_vehiclesToSpawn,SC_liveVehicles,SC_maxNumberofVehicles,time]; 
		[_logDetail] call SC_fnc_log;
	}
	else
	{
		_logDetail = format['[OCCUPATION:Vehicle] Started %2 currently active (max %3) @ %4',_vehiclesToSpawn,SC_liveVehicles,SC_maxNumberofVehicles,time];
		[_logDetail] call SC_fnc_log;
	};
	
};

_middle = worldSize/2;
_spawnCenter = [_middle,_middle,0];
_maxDistance = _middle;

if(_vehiclesToSpawn >= 1) then
{
    if(SC_occupyVehicleSurvivors) then
    {
        // decide which side to spawn
        _sideToSpawn = random 100; 
        if(_sideToSpawn <= SC_SurvivorsChance) then  
        { 
            _side = "survivor";   
        };         
    };
 
	_useLaunchers = DMS_ai_use_launchers;
 	for "_j" from 1 to _vehiclesToSpawn do
	{
		private["_group"];
        _spawnLocation = [ true, false ] call SC_fnc_findsafePos;
        diag_log format["[OCCUPATION:Vehicle] found position %1",_spawnLocation];
        _group = createGroup SC_BanditSide;
        if(_side == "survivor") then 
        { 
            deleteGroup _group;
            _group = createGroup SC_SurvivorSide; 
        };        
        
        _group setVariable ["DMS_LockLocality",nil];
        _group setVariable ["DMS_SpawnedGroup",true];
        _group setVariable ["DMS_Group_Side", _side];        
        
        _VehicleClass = SC_VehicleClassToUse call BIS_fnc_selectRandom;
        _VehicleClassToUse = _VehicleClass select 0;
        vehicleOkToSpawn = false;
        
		// Percentage chance to spawn a rare vehicle
		_rareChance = round (random 100);
		if(_rareChance >= 90) then 
        {
            
            while{!vehicleOkToSpawn} do
            {
                _VehicleClass = SC_VehicleClassToUseRare call BIS_fnc_selectRandom;
                _VehicleClassToUse = _VehicleClass select 0;
                _VehicleClassAllowedCount = _VehicleClass select 1;
                _vehicleCount = 0;
                {
                    if(_VehicleClassToUse == typeOf _x) then { _vehicleCount = _vehicleCount + 1; };    
                }forEach SC_liveVehiclesArray;
                if(_vehicleCount < _VehicleClassAllowedCount OR _VehicleClassAllowedCount == 0) then { vehicleOkToSpawn = true; };
            };             
        }
        else
        { 
            while{!vehicleOkToSpawn} do
            {
                _VehicleClass = SC_VehicleClassToUse call BIS_fnc_selectRandom;
                _VehicleClassToUse = _VehicleClass select 0;
                _VehicleClassAllowedCount = _VehicleClass select 1;
                _vehicleCount = 0;
                {
                    if(_VehicleClassToUse == typeOf _x) then { _vehicleCount = _vehicleCount + 1; };    
                }forEach SC_liveVehiclesArray;
                if(_vehicleCount < _VehicleClassAllowedCount OR _VehicleClassAllowedCount == 0) then { vehicleOkToSpawn = true; };
            };                            
        };
		
        
		_vehicle = createVehicle [_VehicleClassToUse, _spawnLocation, [], 0, "NONE"];
        
        if(!isNull _vehicle) then
        {
            _group addVehicle _vehicle;	
        
            SC_liveVehicles = SC_liveVehicles + 1;
            SC_liveVehiclesArray = SC_liveVehiclesArray + [_vehicle];

            _vehicle setVariable["vehPos",_spawnLocation,true];
            _vehicle setVariable["vehClass",_VehicleClassToUse,true];
            _vehicle setVariable ["SC_vehicleSpawnLocation", _spawnLocation,true];
            _vehicle setFuel 1;
            _vehicle engineOn true;
            
            if(SC_occupyVehiclesLocked) then 
            {
                _vehicle lock 2;			
                _vehicle setVehicleLock "LOCKED";
                _vehicle setVariable ["ExileIsLocked", 1, true];            
            }
            else
            {
                _vehicle lock 0;			
                _vehicle setVehicleLock "UNLOCKED";
                _vehicle setVariable ["ExileIsLocked", 0, true];             
            };

            _vehicle setSpeedMode "LIMITED";
            _vehicle limitSpeed 60;
            _vehicle action ["LightOn", _vehicle];			
            _vehicle addEventHandler ["getin", "_this call SC_fnc_getIn;"];
            _vehicle addEventHandler ["getout", "_this call SC_fnc_getOut;"];
            _vehicle addMPEventHandler ["mpkilled", "_this call SC_fnc_vehicleDestroyed;"];
            _vehicle addMPEventHandler ["mphit", "_this call SC_fnc_hitLand;"];		
        

            
    
            // Calculate the number of seats in the vehicle and fill the required amount
            _crewRequired = SC_minimumCrewAmount;
            if(SC_maximumCrewAmount > SC_minimumCrewAmount) then 
            { 
                _crewRequired = ceil(random[SC_minimumCrewAmount,SC_maximumCrewAmount-SC_minimumCrewAmount,SC_maximumCrewAmount]); 
            };       
            _amountOfCrew = 0;
            _unitPlaced = false;
            _vehicleRoles = (typeOf _vehicle) call bis_fnc_vehicleRoles;
            {
                _unitPlaced = false;
                _vehicleRole = _x select 0;
                _vehicleSeat = _x select 1;
                if(_vehicleRole == "Driver") then
                {
                    _loadOut = [_side] call SC_fnc_selectGear;
                    _unit = [_group,_spawnLocation,"custom","random",_side,"Vehicle",_loadOut] call DMS_fnc_SpawnAISoldier;
                    _unitName = [_side] call SC_fnc_selectName;
                    _unit setName _unitName; 
                    _amountOfCrew = _amountOfCrew + 1;
                    _unit disableAI "FSM";    
                    _unit disableAI "MOVE";         
                    [_side,_unit] call SC_fnc_addMarker;  
                    _unit removeAllMPEventHandlers  "mphit";
                    _unit removeAllMPEventHandlers  "mpkilled";                                            
                    _unit disableAI "TARGET";
                    _unit disableAI "AUTOTARGET";
                    _unit disableAI "AUTOCOMBAT";
                    _unit disableAI "COVER";  
                    _unit disableAI "SUPPRESSION";                   
                    _unit assignAsDriver _vehicle;
                    _unit moveInDriver _vehicle;                
                    _unit setVariable ["DMS_AssignedVeh",_vehicle];
                    _unit setVariable ["SC_drivenVehicle", _vehicle,true]; 
                    _unit addMPEventHandler ["mpkilled", "_this call SC_fnc_driverKilled;"];
                    _vehicle setVariable ["SC_assignedDriver", _unit,true];	

                };
                if(_vehicleRole == "Turret" && _amountOfCrew < _crewRequired) then
                {
                    _loadOut = [_side] call SC_fnc_selectGear;
                    _unit = [_group,_spawnLocation,"custom","random",_side,"Vehicle",_loadOut] call DMS_fnc_SpawnAISoldier;
                    _unitName = [_side] call SC_fnc_selectName;
                    _unit setName _unitName;   
                    _amountOfCrew = _amountOfCrew + 1;                            
                    [_side,_unit] call SC_fnc_addMarker;                            
                    _unit moveInTurret [_vehicle, _vehicleSeat];
                    _unit setVariable ["DMS_AssignedVeh",_vehicle];
                    _unit addMPEventHandler ["mpkilled", "_this call SC_fnc_unitMPKilled;"]; 
                    _unitPlaced = true;
                };
                if(_vehicleRole == "CARGO" && _amountOfCrew < _crewRequired) then
                {
                    _loadOut = [_side] call SC_fnc_selectGear;
                    _unit = [_group,_spawnLocation,"custom","random",_side,"Vehicle",_loadOut] call DMS_fnc_SpawnAISoldier; 
                    _unitName = [_side] call SC_fnc_selectName;
                    _unit setName _unitName;                  
                    _amountOfCrew = _amountOfCrew + 1;           
                    [_side,_unit] call SC_fnc_addMarker;                                               
                    _unit assignAsCargo _vehicle; 
                    _unit moveInCargo _vehicle;
                    _unit setVariable ["DMS_AssignedVeh",_vehicle];
                    _unit addMPEventHandler ["mpkilled", "_this call SC_fnc_unitMPKilled;"]; 
                    _unitPlaced = true; 
                };    
                if(SC_extendedLogging && _unitPlaced) then 
                { 
                    _logDetail = format['[OCCUPATION:Vehicle] %1 %2 added to vehicle %3',_side,_vehicleRole,_vehicle]; 
                    [_logDetail] call SC_fnc_log;
                };  
                if(_amountOfCrew == _crewRequired) exitWith{};                
            } forEach _vehicleRoles;			

            // Get the AI to shut the fuck up :)
            enableSentences false;
            enableRadio false;

            _logDetail = format['[OCCUPATION:Vehicle] %3 vehicle %1 spawned @ %2',_VehicleClassToUse,_spawnLocation,_side]; 
            [_logDetail] call SC_fnc_log;
            sleep 2;
            
            {
                _x enableAI "FSM"; 
                _x enableAI "MOVE";     
            }forEach units _group;
            
            [_group, _spawnLocation, 2000] call bis_fnc_taskPatrol;
            _group setBehaviour "SAFE";
            _group setCombatMode "RED";
            sleep 0.2;
            
            clearMagazineCargoGlobal _vehicle;
            clearWeaponCargoGlobal _vehicle;
            clearItemCargoGlobal _vehicle;

            _vehicle addMagazineCargoGlobal ["HandGrenade", (random 2)];
            _vehicle addItemCargoGlobal     ["ItemGPS", (random 1)];
            _vehicle addItemCargoGlobal     ["Exile_Item_InstaDoc", (random 1)];
            _vehicle addItemCargoGlobal     ["Exile_Item_PlasticBottleFreshWater", 2 + (random 2)];
            _vehicle addItemCargoGlobal     ["Exile_Item_EMRE", 2 + (random 2)];
            
            // Add weapons with ammo to the vehicle
            _possibleWeapons = 
            [			
                "arifle_MXM_Black_F",
                "arifle_MXM_F",
                "arifle_MX_SW_Black_F",
                "arifle_MX_SW_F",
                "LMG_Mk200_F",
                "LMG_Zafir_F"
            ];
            _amountOfWeapons = 1 + (random 3);
            
            for "_i" from 1 to _amountOfWeapons do
            {
                _weaponToAdd = _possibleWeapons call BIS_fnc_selectRandom;
                _vehicle addWeaponCargoGlobal [_weaponToAdd,1];
            
                _magazinesToAdd = getArray (configFile >> "CfgWeapons" >> _weaponToAdd >> "magazines");
                _vehicle addMagazineCargoGlobal [(_magazinesToAdd select 0),round random 3];
            };    
        }
        else
        {
            _logDetail = format['[OCCUPATION:Vehicle] vehicle %1 failed to spawn (check classname is correct)',_VehicleClassToUse]; 
            [_logDetail] call SC_fnc_log; 
        };
	};
};

_logDetail = format['[OCCUPATION:Vehicle] End check %1 currently active (max %2) @ %3',SC_liveVehicles,SC_maxNumberofVehicles,time]; 
[_logDetail] call SC_fnc_log;