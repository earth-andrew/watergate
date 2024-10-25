extensions [bitmap csv]

breed [borders border]
breed [thick-borders thick-border]
;breed [counters counter]
breed [buttons button]
breed [player-actions player-action]
breed [arrows arrow]
breed [selections selection]
breed [actions action]
breed [plusses plus]
breed [minuses minus]
breed [barSquares barSquare]
breed [waterSupplyRounds waterSupplyRound]
breed [integer-agents integer-agent]


actions-own [ID	action_name	cost	demand benefit damage-dry damage-wet amt_max amt_min req duration]
patches-own [inGame? playerAccess]
;counters-own [identity]
buttons-own [identity value]
arrows-own [identity menu at-end]
selections-own [row column ID visibleTo showing ]
plusses-own [ID visibleTo showing]
minuses-own [ID visibleTo showing]
player-actions-own [ID visibleTo counter]
barSquares-own [ID visibleTo]
waterSupplyRounds-own [roundID upstream_min upstream_max downstream_min downstream_max]
integer-agents-own [ID visibleTo summaryOf]


globals [
  ;;game mechanism values
  numPlayers
  playerNames
  playerTeams
  playerDemand
  playerPosition
  playerConfirm
  playerCounts
  playerCurrentScore
  playerActions_Access
  playerTotalScore
  messageAddressed
  gameInProgress
  langSuffix
  patches_game
  patches_panel
  border_player_summary
  border_actions
  arrow_area
  player_actions_y
  player_actions_size
  actionInputs
  action_property_labels
  waterInputs
  water_property_labels
  actionCostList
  actionBenefitList
  endowment
  upstream
  downstream
  teamDemand
  teamReceipt
  upstreamWaterSupply
  downstreamWaterSupply
  upstreamVolume
  downstreamVolume
  upstream_initial
  downstream_initial
  downstream_drainage
  downstream_share
  upstreamWaterReceipt
  downstreamWaterReceipt
  upstream_basin_max
  downstream_basin_max
  upstreamX
  upstreamY
  upstreamW
  upstreamH
  downstreamX
  downstreamY
  downstreamW
  downstreamH
  gate_settings

  numRounds
  phasesPerRound
  currentRound
  currentPhase

  playerActions
  playerActionsDuration
  playerCurrentSelections
  playerCurrentResources
  playerResources
  playerGateChoice

  ;;visualization parameters and variables
  colorList
  border_color
  playerColor
  number_shape_list
  confirm_area
  confirm-up-color
  confirm-down-color
  access_shading
  in_game_color
  arrowEndColor
  arrowNotEndColor
  action_w
  action_h
  plusminus_rel_size

  gate_button_size
  gate_button_center_y

  ;;variables related to parsing parameter input
  gameID
  gameName
  actionListFileName
  waterSupplyFileName
  currentSessionParameters
  completedGamesIDs
  parsedInput
  inputFileLabels
  sessionList

  ;;variables for storing local variables that can be called and set by anonymous and user-input functions
  tempLocal
  parameterHandled


  ]



to initialize-session

  ;; stop if we are currently in a session
  if (length currentSessionParameters > 0)
  [user-message "Current session is not complete.  Please continue current session.  Otherwise, to start new session, please first clear settings by clicking 'Launch Broadcast'"
    stop]

  ;; if the session requested isn't in our input parameters, stop
  if (not member? sessionID sessionList)
  [user-message "Session ID not found in input records"
    stop]

  ;; if the session requested has prior game data available, let the user know
  if (member? sessionID completedGamesIDs)
  [user-message "Warning: At least one game file with this sessionID has been found"]

  ;; pick the appropriate set of parameters for the current session from the previously parsed input file (i.e., all games listed as part of session 1)
  set currentSessionParameters filter [ ?1 -> item 0 ?1 = sessionID ] parsedInput

end

to start-hubnet
  ;; do everything here that needs to be done before all games, and will be preserved for all games

  ;; clean the slate
  clear-all

  ;; clear anything from the display, just in case
  clear-ticks
  clear-patches
  clear-turtles
  clear-drawing

  ;; reset the hubnet
  hubnet-reset

  ;; set all session variables that are preserved across games
  set playerNames (list)
  set playerPosition (list)
  set playerColor (list)
  set numPlayers 0
  set gameInProgress 0
  set-default-shape borders "line"
  set-default-shape thick-borders "line-thick"
  set-default-shape actions "blank"
  set-default-shape arrows "activity-arrow"
  set-default-shape selections "selection-rectangle"
  set-default-shape plusses "badge-plus"
  set-default-shape minuses "badge-minus"
  set-default-shape barSquares "square-full"

  set patches_game 7
  set patches_panel 5
  set border_player_summary 1
  set border_actions 4
  set player_actions_y 1
  set player_actions_size 0.8
  set arrow_area patches_panel / 5
  set plusminus_rel_size 0.4

  set border_color 5
  set colorList (list 95 15 25 115 125 5 135 93 13 23 113 123 3 133 98 18 28 118 128 8 138)  ;; add to this if you will have more than 21 players, but really, you shouldn't!!!
  set number_shape_list (list "num-0" "num-1" "num-2" "num-3" "num-4" "num-5" "num-6" "num-7" "num-8" "num-9")
  set confirm-up-color lime
  set confirm-down-color 61
  set access_shading (- 3)
  set in_game_color green
  set arrowEndColor gray
  set arrowNotEndColor blue

  set action_w 4
  set action_h 1

    ;; try to read in the input parameter data - stop if the file doesn't exist
  if not file-exists? inputParameterFileName [ ;;if game parameter file is incorrect
    user-message "Please enter valid file name for input data"
    stop
  ]

  ;; open the file and read it in line by line
  set parsedInput csv:from-file inputParameterFileName
  set inputFileLabels item 0 parsedInput
  set sessionList []
  foreach but-first parsedInput [ ?1 -> set sessionList lput (item 0 ?1) sessionList ]
  set sessionList remove-duplicates sessionList

  ;; look in the list of completed game IDs, and take an initial guess that the session of interest is one higher than the highest session completed previously
  set completedGamesIDs []
  ifelse file-exists? "completedGames.csv" [
  file-open "completedGames.csv"
  while [not file-at-end?] [
    let tempValue file-read-line
    set completedGamesIDs lput read-from-string substring tempValue 0 position "_" tempValue completedGamesIDs
  ]
  set completedGamesIDs remove-duplicates completedGamesIDs
  set sessionID max completedGamesIDs + 1
  file-close
  ] [
  set sessionID -9999
  ]


  set currentSessionParameters []

end

to set-game-parameters

  ;; this procedure takes the list of parameters names and values and processes them for use in the current game

  ;; take the current game's set of parameters
  let currentGameParameters item 0 currentSessionParameters
  set currentSessionParameters sublist currentSessionParameters 1 length currentSessionParameters

  ;; there are two lists - one with variable names, one with values
  (foreach inputFileLabels currentGameParameters [ [?1 ?2] -> ;; first element is variable name, second element is value

    ;; we use a 'parameter handled' structure to avoid having nested foreach statements
    set parameterHandled 0

    output-print " "
    output-print "Relevant Game Parameters:"
    output-print " "


    ;; requirement list and phase shown list may come in as a single value, or may be multiple values
    if parameterHandled = 0 and (?1 = "upstream" or ?1 = "gate_settings") [  ;; any other case
      file-print (word ?1 ": " ?2 )
      let currentParameter []
      set currentParameter (word "set " ?1 " (list " ?2 ")" )

      run currentParameter
      set parameterHandled 1
    ]

    ;; all other cases not specified above are handled as below - the parameter of the same name is set to the specified value
    if parameterHandled = 0 [  ;; any other case
                               ;;output-print (word ?1 ": " ?2 )
      file-print (word ?1 ": " ?2 )
      let currentParameter []
      ifelse is-string? ?2 [
        set currentParameter (word "set " ?1 "  \"" ?2 "\"" )
      ][
        set currentParameter (word "set " ?1 " " ?2 )
      ]
      set tempLocal currentParameter
      run currentParameter

      set parameterHandled 1
    ]

  ])
  file-print ""

  output-print " "
  output-print " "

end

to start-game

  ;; stop if a game is already running
  if (gameInProgress = 1)
  [user-message "Current game is not complete.  Please continue current game.  Otherwise, to start new session, please first clear settings by clicking 'Launch Broadcast'"
    stop]

  ;; stop if there are no more game parameters queued up
  if (length currentSessionParameters = 0)
  [user-message "No games left in session.  Re-initialize or choose new session ID"
    stop]

  ;; clear the output window and display
  clear-output
  clear-patches
  clear-turtles
  clear-drawing
  foreach playerPosition [ ?1 ->
    hubnet-clear-overrides (item (?1 - 1) playerNames)
  ]
  output-print "Output/Display cleared."


  ;; Start the game output file
  ;; the code below builds the game output file, named by the players and the current timestamp
  let tempDate date-and-time
  foreach [2 5 8 12 15 18 22] [ ?1 -> set tempDate replace-item ?1 tempDate "_" ]
  let playerNameList (word (item 0 playerNames) "_")
  foreach n-values (numPlayers - 1) [ ?1 ->  ?1 + 1 ] [ ?1 ->
   set playerNameList (word playerNameList "_" (item ?1 playerNames))
  ]
  set gameName (word gameID "_" playerNameList "_" tempDate ".csv" )
  carefully [file-delete gameName file-open gameName] [file-open gameName]
  output-print "Game output file created."


  ;;set parameters for this game
  set-game-parameters

  ;;read in actions, water file
  read-action-file
  read-water-file

  ;;Set any parameters not set earlier, and not to be set from the read-in game file
  set playerCounts n-values numPlayers [0]
  set playerConfirm n-values numPlayers [0]
  set playerCurrentScore n-values numPlayers [0]
  set playerTotalScore n-values numPlayers [0]
  set playerResources n-values numPlayers [endowment]
  set playerCurrentResources n-values numPlayers [0]
  set playerTeams n-values numPlayers [1]
  set playerGateChoice n-values numPlayers [0]

  set upstreamVolume upstream_initial
  set downstreamVolume downstream_initial
  set downstream_share 0

  set upstreamX -0.25
  set upstreamY 0.75
  set upstreamW 3
  set upstreamH 2
  set downstreamX 3.25
  set downstreamY -0.25
  set downstreamW 3
  set downstreamH 2

  set gate_button_size 0.5
  set gate_button_center_y patches_game / 2

  foreach upstream [?1 ->
    if ?1 < length playerTeams [
      set playerTeams replace-item ?1 playerTeams 0
    ]
  ]

   ;; set up lists for number of each actions selected by player
  set playerActions n-values numPlayers [0]
  set playerActionsDuration n-values numPlayers [0]
  set playerCurrentSelections n-values numPlayers [0]
  set playerDemand n-values numPlayers [0]
  set playerGateChoice n-values numPlayers [0]
  let playerActionList n-values count actions [0]
  let playerActionDurationList n-values count actions [(list)]
  let playerSelectionList n-values count actions [0]
  let demandList n-values length [demand] of one-of actions [0]

  set upstreamWaterReceipt n-values numRounds [n-values phasesPerRound [0]]
  set downstreamWaterReceipt upstreamWaterReceipt
  set teamReceipt n-values 2 [n-values phasesPerRound [0]]

  foreach n-values (numPlayers) [?1 -> ?1] [ ?1 ->
    set playerActions replace-item ?1 playerActions playerActionList
    set playerActionsDuration replace-item ?1 playerActionsDuration playerActionDurationList
    set playerCurrentSelections replace-item ?1 playerCurrentSelections playerSelectionList
    set playerDemand replace-item ?1 playerDemand demandList
  ]


  set teamDemand (list demandList demandList)

  set playerActions_Access playerActions

  ;set-default-shape borders "line"
  output-print "Game parameters initialized."




  ;;lay out the game board

  resize-world (- patches_panel) (patches_game - 1) 0 (patches_game - 1)

  ;;make the confirm button
  set confirm_area (list (- 2.5) (patches_game - 1.7) 1.8 0.9)
    create-buttons 1 [setxy (item 0 confirm_area + (item 2 confirm_area / 2)) (item 1 confirm_area + (item 3 confirm_area / 2)) set size item 2 confirm_area set color confirm-up-color set identity "confirm" set shape "confirm"]

  ;; separate the game land from the display area, and seed the landscape
  ask patches [
    if-else (pxcor < 0) [
      set inGame? false


    ][
      set inGame? true


    ]
  ]

  ;;show divisions between patches
  make-borders
  draw-basins

  ;;add arrows
  let tempMenu n-values numPlayers [0]
  create-arrows 1 [setxy ( - arrow_area / 2 - 0.5) (border_player_summary + (border_actions - border_player_summary) * 3 / 4 + 0.5) set heading 0 set size 1 set identity "up" set menu tempMenu set at-end tempMenu]
  create-arrows 1 [setxy ( - arrow_area / 2 - 0.5) (border_player_summary + (border_actions - border_player_summary) * 1 / 4 + 0.5) set heading 180 set size 1 set identity "down" set menu tempMenu set at-end tempMenu]

  ;;add actions
  add-actions

   foreach n-values numPlayers [?1 -> ?1] [ ?1 ->


    update-access ?1
    update-displayed-actions ?1

    update-player-actions ?1
  ]

  set gameInProgress 1

  ;;make a round counter visible to all
  set currentRound 1
  set currentPhase 0
  integer-as-agents currentRound 1 red (- 4.5) 5.7 (n-values numPlayers [?1 -> ?1]) "round"
  integer-as-agents currentPhase 0.5 blue (- 4) 5.5 (n-values numPlayers [?1 -> ?1]) "phase"


  ;;fill the basins
  ask one-of turtles [
    draw-bar-chart upstreamX upstreamY upstreamW upstreamH 0 upstream_basin_max blue (list round(upstreamVolume)) (n-values numPlayers [ i -> i ])  "upstream_volume" false
    draw-bar-chart downstreamX downstreamY downstreamW downstreamH 0 downstream_basin_max blue (list round(downstreamVolume)) (n-values numPlayers [ i -> i ])  "downstream_volume" false
  ]
  integer-as-agents round(upstreamVolume) 1 white 1 1.25 (n-values numPlayers [?1 -> ?1]) "upstream_volume"
  integer-as-agents round(downstreamVolume) 1 white 4.5 0.25 (n-values numPlayers [?1 -> ?1]) "downstream_volume"


  ;;make the gate buttons
  let top_button_y gate_button_center_y + (((length gate_settings) - 1) / 2) * gate_button_size
  let gate_counter 0
  foreach gate_settings [ ?1 ->
    create-buttons 1 [
      set size gate_button_size
      set shape "square outline"
      set color 98
      set value ?1
      setxy ((patches_game / 2) - 0.5) (top_button_y - gate_counter * gate_button_size)
      set identity "gate_setting"

    ]
    integer-as-agents (item gate_counter gate_settings) 0.3 white ((patches_game / 2) - 0.55) (top_button_y - gate_counter * gate_button_size) (n-values numPlayers [?2 -> ?2]) "gate_setting"
    set gate_counter gate_counter + 1

  ]


  create-buttons 1 [set size 0.5 setxy -1.9 5 set color white set shape "square" set identity "team1"]
  create-buttons 1 [set size 0.5 setxy -1.4 4.8 set color white set shape "square" set identity "team2"]
  foreach n-values (numPlayers) [?1 -> ?1] [ ?1 ->
    if-else item ?1 playerTeams = 0 [ ;;upstream team
      ask buttons with [identity = "team2"] [hubnet-send-override (item ?1 playerNames) self "shape" ["square outline"]]
    ] [
      ask buttons with [identity = "team1"] [hubnet-send-override (item ?1 playerNames) self "shape" ["square outline"]]
      ]
  ]


  ask buttons with [identity = "gate_setting"][set hidden? true]
  ask integer-agents with [ID = "gate_setting"][set hidden? true]

end


to add-actions

  let actions_per_row floor ((patches_panel  - arrow_area) / action_w)
  let action_rows  floor ((border_actions - border_player_summary ) / action_h)


  ;;how much empty space do we need to account for
  let x_spacer (patches_panel - arrow_area - actions_per_row * action_w) / actions_per_row
  let y_spacer (border_actions - border_player_summary - action_rows * action_h) / action_rows

  ;; now we know how many will fit in our space (action_rows by actions_per_row
  ;; place them starting from the top
  let selectionCounter 0
  foreach n-values (action_rows) [ ?1 ->  ?1 + 1 ] [ ?1 ->
    let row_num ?1
    foreach n-values (actions_per_row) [ ?2 ->  ?2 + 1 ] [ ?2 ->
      let col_num ?2
      set selectionCounter selectionCounter + 1
      create-selections 1 [setxy (- patches_panel + (action_h + x_spacer) * (col_num - 1) + (action_h + x_spacer) / 2 - 0.5) (border_actions - (action_h + y_spacer) * (row_num - 1) - (action_h + y_spacer) / 2 + 0.5)
        set size action_h
        set ID selectionCounter
        set visibleTo n-values numPlayers [0]
        set showing n-values numPlayers [0]
      ]

      create-plusses 1 [setxy (- patches_panel + (action_w + x_spacer) * (col_num - 1) + (action_w + x_spacer) * 7 / 8 - 0.5) (border_actions - (action_h + y_spacer) * (row_num - 1) - (action_h + y_spacer) * 1 / 4 + 0.5 )
        set size action_h * plusminus_rel_size
        set color gray
        set ID selectionCounter
        set visibleTo n-values numPlayers [0]
        set showing visibleTo
      ]
      create-minuses 1 [setxy (- patches_panel + (action_w + x_spacer) * (col_num - 1) + (action_w + x_spacer) * 7 / 8 - 0.5) (border_actions - (action_h + y_spacer) * (row_num - 1) - (action_h + y_spacer) * 3 / 4 + 0.5 )
        set size action_h * plusminus_rel_size
        set color gray
        set ID selectionCounter
        set visibleTo n-values numPlayers [0]
        set showing visibleTo
      ]
    ]
  ]


end


to update-access [playerNumber]



  let accessList n-values count actions [1]


  ask actions [


    ;; for those that have requirements, check which players meet the reqs - if they miss any
    ;; of them, set to zero UNLESS that requirement has a non-zero 'supply_per' and someone else has it
    foreach req [ ?1 ->


     if item (?1 - 1) (item playerNumber playerActions) = 0 [ ;; if the player doesn't have this requirement


        set accessList replace-item (ID - 1) accessList 0

      ]
    ]

  ]


  set playerActions_Access replace-item (playerNumber) playerActions_Access accessList

  ;;make sure the arrow settings are appropriate to the new access menu
  if-else sum accessList <= count selections [

    ;; the player only needs one menu, so the arrows should indicate this
    ask arrows [set at-end replace-item (playerNumber) at-end 1]
  ][


    ask arrows with [identity = "up"] [set at-end replace-item (playerNumber) at-end 1]
    ask arrows with [identity = "down"] [set at-end replace-item (playerNumber) at-end 0]
  ]


  ask arrows [set menu replace-item (playerNumber) menu 0]

end

to update-displayed-actions [playerNumber]

  ;;kill the numbers that were previously there
  ask integer-agents with [member? playerNumber visibleTo and member? "display-action" ID] [die]
  ask integer-agents with [member? playerNumber visibleTo and ID = "demand" ] [die]
  ask barSquares with [member? playerNumber visibleTo and ID = "demand"] [die]

  ;;find out which menu we should be looking at
  let currentMenuCount item (playerNumber) [menu] of one-of arrows with [identity = "up"]

  let accessList item playerNumber playerActions_Access


  ;;make ordered list of all displayable actions
  let available-actions sort-on [ID] actions with [item (ID - 1) accessList > 0]

  ask selections [hubnet-send-override (item (playerNumber) playerNames) self "shape" ["blank"] set visibleTo replace-item playerNumber visibleTo 0 set showing replace-item playerNumber showing 0]
  ask plusses [hubnet-send-override (item (playerNumber) playerNames) self "shape" ["blank"] set visibleTo replace-item playerNumber visibleTo 0 set showing replace-item playerNumber showing 0]
  ask minuses [hubnet-send-override (item (playerNumber) playerNames) self "shape" ["blank"] set visibleTo replace-item playerNumber visibleTo 0 set showing replace-item playerNumber showing 0]

  if not empty? available-actions [
    set available-actions sublist available-actions (currentMenuCount * count selections) (length available-actions)



    ;;show the available actions

    foreach sort-on [ID] selections [ ?1 ->
      ask ?1 [


        let myCounter ID
        if not empty? available-actions [
          let currentID [ID] of first available-actions
          hubnet-send-override (item (playerNumber) playerNames) self "shape" [[action_name] of first available-actions]
          set visibleTo replace-item playerNumber visibleTo 1
          set showing replace-item playerNumber showing currentID
          let myShowing item playerNumber showing

          ;;show the cost and benefit of doing this
          integer-as-agents ([cost] of one-of actions with [ID = myShowing]) 0.4 pink (xcor + size) (ycor + size / 4) (list playerNumber) "display-actionCost"
          integer-as-agents ([benefit] of one-of actions with [ID = myShowing]) 0.4 green (xcor + size) (ycor - size / 4) (list playerNumber) "display-actionBenefit"


          ;;show the water demand path
          draw-bar-chart (xcor + 1.4) (ycor - 0.3) 1.5 1 0.1 10 blue ([demand] of first available-actions) (list playerNumber) "demand" true

          ask plusses with [ID = myCounter] [hubnet-send-override (item (playerNumber) playerNames) self "shape" ["badge-plus"]
            set visibleTo replace-item playerNumber visibleTo 1
            ;show (word "currentAction " currentID )
            ;show (word "player " playerNumber)
            update-colors currentID playerNumber
            set showing replace-item playerNumber showing currentID]
          ask minuses with [ID = myCounter] [hubnet-send-override (item (playerNumber) playerNames) self "shape" ["badge-minus"]
            set visibleTo replace-item playerNumber visibleTo 1
            update-colors currentID playerNumber
            set showing replace-item playerNumber showing currentID]

          set available-actions but-first available-actions
        ]
      ]

    ]

  ]

  ;;make sure the arrows appropriately reflect availability of menus
  ask arrows [

    if-else item playerNumber at-end = 0 [

      hubnet-send-override (item playerNumber playerNames) self "color" [arrowNotEndColor]
    ][

        hubnet-send-override (item playerNumber playerNames) self "color" [arrowEndColor]
    ]
  ]


end

to draw-basins

  ;;upstream basin
  ask patches with [pxcor = 0 and pycor < 4 and pycor > 1 ] [
    sprout-thick-borders 1 [set color white
      setxy pxcor - 0.25 pycor - 0.75
      set heading 0
      stamp die]
  ]

  ask patches with [pxcor = 3 and pycor < 4 and pycor > 1 ] [
    sprout-thick-borders 1 [set color white
      setxy pxcor - 0.25 pycor - 0.75
      set heading 0
      stamp die]
  ]

  ask patches with [pxcor >= 0 and pxcor < 3 and pycor = 1] [
    sprout-thick-borders 1 [set color white
      setxy pxcor + 0.25 pycor - 0.25
      set heading 90
      stamp die]
  ]

  ;;downstream basin
  ask patches with [pxcor = 3 and pycor < 3 and pycor > 0 ] [
    sprout-thick-borders 1 [set color white
      setxy pxcor + 0.25 pycor - 0.75
      set heading 0
      stamp die]
  ]

  ask patches with [pxcor = 6 and pycor < 3 and pycor > 0 ] [
    sprout-thick-borders 1 [set color white
      setxy pxcor + 0.25 pycor - 0.75
      set heading 0
      stamp die]
  ]

  ask patches with [pxcor > 3 and pxcor <= 7 and pycor = 0] [
    sprout-thick-borders 1 [set color white
      setxy pxcor - 0.25 pycor - 0.25
      set heading 90
      stamp die]
  ]

  create-buttons 1 [
   set shape "raindrops"
   set size 1
   setxy 0.5 3
  ]

  create-buttons 1 [
   set shape "raindrops"
   set size 1
   setxy 5.5 2
  ]

end


to draw-bar-chart [minX minY width height spacing maxValue barColor barValues seen_by name numbers?]
  let numBars length barValues
  let widthBar width / numBars
  set widthBar widthBar - spacing


  let sizeSquare widthBar
  let numSquaresW 1
  let numSquaresH 1
  let overlapW 0
  let overlapH 0


  foreach n-values (numBars)[ ?1 ->  ?1 + 1 ] [ ?1 ->

    let currentHeight item (?1 - 1) barValues
    let currentHeightPatches (min list height (currentHeight / maxValue * height))


    if-else currentHeightPatches < widthBar [ ;;bar is shorter than it is wide

      if currentHeightPatches > 0 [
        set sizeSquare currentHeightPatches

        set numSquaresW ceiling (widthBar / sizeSquare) + 3


        set overlapW (widthBar - sizeSquare) / (numSquaresW - 1)
        foreach n-values numSquaresW [ ?2 ->  ?2 + 1 ] [ ?2 ->
          hatch-barSquares 1 [
            setxy (minX + (sizeSquare / 2) + (?1 - 1) * (widthBar + spacing) + (?2 - 1) * overlapW) minY + (sizeSquare / 2)

            set hidden? false
            set size sizeSquare
            set color barColor
            set visibleTo (list)
            set ID name
            foreach n-values (numPlayers) [?3 -> ?3 ] [ ?3 ->

              if-else (member? ?3 seen_by) [
                set visibleTo lput ?3 visibleTo
              ] [
                hubnet-send-override  (item (?3) playerNames) self "shape" ["blank"]
              ]
            ]
          ]
        ]
      ]
    ][ ;;bar is taller than it is wide

      set sizeSquare widthBar

      set numSquaresH ceiling (currentHeightPatches / sizeSquare) + 3
      set overlapH (currentHeightPatches - sizeSquare) / (numSquaresH - 1)
      foreach n-values numSquaresH [ ?2 ->  ?2 + 1 ] [ ?2 ->
        hatch-barSquares 1 [
          setxy minX + (sizeSquare / 2) + (?1 - 1) * (widthBar + spacing)  minY + (?2 - 1) * overlapH + (sizeSquare / 2)
          set size sizeSquare
          set color barColor
          set ID name
          set hidden? false
          set visibleTo (list)


          foreach n-values (numPlayers) [?3 -> ?3 ] [ ?3 ->

          if-else (member? ?3 seen_by) [
            set visibleTo lput ?3 visibleTo
          ] [
            hubnet-send-override  (item (?3) playerNames) self "shape" ["blank"]
          ]
        ]
        ]
      ]

    ]


    if numbers? [
      ;;add numbers to show the water demand
      integer-as-agents currentHeight (widthBar / 2) white (minX + (widthBar / 4) + (?1 - 1) * (widthBar + spacing))  (minY + (widthBar / 2) - 0.2) seen_by name
    ]

  ]




end

to arrow-activity [playerNumber currentIdentity currentMenu]

  let accessList item (playerNumber) playerActions_Access
  let numItems sum accessList
  let sizeMenu count selections


  ;;update the menu number IF we can actually move to a new menu
  if(currentIdentity = "down") and (numItems > sizeMenu * (currentMenu + 1)) [
  ;;request to move down, and there are more items to show
    set currentMenu currentMenu + 1
    ask arrows [set menu replace-item playerNumber menu currentMenu]
  ]

  if(currentIdentity = "up") and (currentMenu > 0) [
  ;;request to move down, and there are more items to show
    set currentMenu currentMenu - 1
    ask arrows [set menu replace-item playerNumber menu currentMenu]
  ]


  ;;make sure all arrows are correctly identified as being at end or not
  ;;make sure the arrow settings are appropriate to the new access menu
  if-else numItems <= sizeMenu * (currentMenu + 1) [
    ;; can't go any further
    ask arrows with [identity = "down"] [set at-end replace-item (playerNumber) at-end 1]
  ][
    ask arrows with [identity = "down"] [set at-end replace-item (playerNumber) at-end 0]
  ]

  if-else currentMenu > 0 [
    ;; can't go any further
    ask arrows with [identity = "up"] [set at-end replace-item (playerNumber) at-end 0]
  ][
    ask arrows with [identity = "up"] [set at-end replace-item (playerNumber) at-end 1]
  ]


  update-displayed-actions playerNumber

end

to plus-activity [currentMessagePosition]

  let myActivity item currentMessagePosition showing
  let currentMax [amt_max] of one-of actions with [ID = myActivity]



  ;;allow for possibility that max values are specified not as numbers but as other variables
  set tempLocal currentMessagePosition

  if is-string? currentMax [ run (word "set tempLocal " currentMax)

    set currentMax tempLocal]


  let currentCost [cost] of one-of actions with [ID = myActivity]

  ;; if we can add more of the current activity, do
  let currentCount item (myActivity - 1) (item currentMessagePosition playerCurrentSelections)
  let potentialCost item currentMessagePosition playerCurrentResources + currentCost
  let budget item currentMessagePosition playerResources


  if (currentCount < currentMax and potentialCost <= budget) [
    set currentCount currentCount + 1
    set playerCurrentSelections (replace-item currentMessagePosition playerCurrentSelections (replace-item (myActivity - 1) (item currentMessagePosition playerCurrentSelections) (currentCount)))


  ]

  update-colors myActivity currentMessagePosition


end

to minus-activity [currentMessagePosition]

 let myActivity item currentMessagePosition showing
  let currentMin [amt_min] of one-of actions with [ID = myActivity]
  let currentCost [cost] of one-of actions with [ID = myActivity]



  ;; if we can subtract more of the current activity, do
  let currentCount item (myActivity - 1) (item currentMessagePosition playerCurrentSelections)
  let potentialCost item currentMessagePosition playerCurrentResources - currentCost
  let budget item currentMessagePosition playerResources
  if (currentCount > currentMin and potentialCost <= budget) [
    set currentCount currentCount - 1
    set playerCurrentSelections (replace-item currentMessagePosition playerCurrentSelections (replace-item (myActivity - 1) (item currentMessagePosition playerCurrentSelections) (currentCount)))


  ]

  update-colors myActivity currentMessagePosition

end


to read-water-file



  set upstreamWaterSupply (list)
  set downstreamWaterSupply (list)

  ;; try to read in the water data - stop if the file doesn't exist
  if not file-exists? waterSupplyFileName [ ;;if game parameter file is incorrect
    user-message "Please enter valid file name for water data"
    stop
  ]

  ;; open the file and read it in line by line
  set waterInputs csv:from-file waterSupplyFileName
  set water_property_labels item 0 waterInputs
  foreach but-first waterInputs [ ?0 ->

    let currentSupply ?0

    create-waterSupplyRounds 1 [
    ;; there are two lists - one with variable names, one with values
    (foreach water_property_labels currentSupply [ [?1 ?2] -> ;; first element is variable name, second element is value

      ;; we use a 'parameter handled' structure to avoid having nested foreach statements, in case there are different ways to handle inputs
      set parameterHandled 0

      ;; requirement list and phase shown list may come in as a single value, or may be multiple values
      if parameterHandled = 0 and (?1 = "upstream_min" or ?1 = "upstream_max" or ?1 = "downstream_min" or ?1 = "downstream_max") [  ;; lists of values
        file-print (word ?1 ": " ?2 )
        let currentParameter []
        set currentParameter (word "set " ?1 " (list " ?2 ")" )

        run currentParameter
        set parameterHandled 1
      ]

        ;; all other cases not specified above are handled as below - the parameter of the same name is set to the specified value
      if parameterHandled = 0 [  ;; any other case
        ;;output-print (word ?1 ": " ?2 )
        file-print (word ?1 ": " ?2 )
        let currentParameter []
        ifelse is-string? ?2 [
          set currentParameter (word "set " ?1 "  \"" ?2 "\"" )
        ][
          set currentParameter (word "set " ?1 " " ?2 )
        ]
        run currentParameter
        set parameterHandled 1
      ]

    ])

      ;;the above is a convenient vehicle for storing information about a round.  now let's construct the actual water supply for this round
      let upstreamWaterRound (list)
      let downstreamWaterRound (list)

      foreach n-values (length upstream_min) [i -> i] [i ->
        set upstreamWaterRound lput ((item i upstream_min) + random ((item i upstream_max + 1) - (item i upstream_min))) upstreamWaterRound
        set downstreamWaterRound lput ((item i downstream_min) + random ((item i downstream_max + 1) - (item i downstream_min))) downstreamWaterRound
      ]

      set upstreamWaterSupply lput upstreamWaterRound upstreamWaterSupply
      set downstreamWaterSupply lput downstreamWaterRound downstreamWaterSupply

      die
    ]
  ]

  output-print "Water supply file read."


end

to read-action-file



  ;; try to read in the input parameter data - stop if the file doesn't exist
  if not file-exists? actionListFileName [ ;;if game parameter file is incorrect
    user-message "Please enter valid file name for action data"
    stop
  ]

  ;; open the file and read it in line by line
  set actionInputs csv:from-file actionListFileName
  set action_property_labels item 0 actionInputs
  foreach but-first actionInputs [ ?0 ->

    let currentAction ?0

    create-actions 1 [
    ;; there are two lists - one with variable names, one with values
    (foreach action_property_labels currentAction [ [?1 ?2] -> ;; first element is variable name, second element is value

      ;; we use a 'parameter handled' structure to avoid having nested foreach statements, in case there are different ways to handle inputs
      set parameterHandled 0

      ;; requirement list and phase shown list may come in as a single value, or may be multiple values
      if parameterHandled = 0 and (?1 = "req" or ?1 = "demand" or ?1 = "damage-dry" or ?1 = "damage-wet") [  ;; any other case
        file-print (word ?1 ": " ?2 )
        let currentParameter []
        set currentParameter (word "set " ?1 " (list " ?2 ")" )

        run currentParameter
        set parameterHandled 1
      ]

        ;; all other cases not specified above are handled as below - the parameter of the same name is set to the specified value
      if parameterHandled = 0 [  ;; any other case
        ;;output-print (word ?1 ": " ?2 )
        file-print (word ?1 ": " ?2 )
        let currentParameter []
        ifelse is-string? ?2 [
          set currentParameter (word "set " ?1 "  \"" ?2 "\"" )
        ][
          set currentParameter (word "set " ?1 " " ?2 )
        ]
        run currentParameter
        set parameterHandled 1
      ]

    ])

    ]
  ]

  set actionCostList n-values (count actions) [0]
  set actionBenefitList n-values (count actions) [0]
  foreach n-values (count actions) [ ?1 -> ?1 + 1] [ ?1 ->

    ask one-of actions with [ID = ?1] [
      set actionCostList replace-item (?1 - 1) actionCostList cost
      set actionBenefitList replace-item (?1 - 1) actionBenefitList benefit
    ]

  ]

  output-print "Action file read."


end

to update-team-actions [teamID teamName offsetX]
  ;;update the array of  actions taken in the player panel



  ;;kill whatever was there before
  ask player-actions with [member? teamName ID ] [die]

  ask integer-agents with [ ID = teamName] [die]
  ask barSquares with [ID = teamName ] [die]



  ;;;;;;;;;;;;;;;;;;;;;
  ;;count how many unique actions there are for badges
  let currentItemList (list)
  let currentCountList (list)
  let currentActionList n-values count actions [0]
  foreach n-values numPlayers [?1 -> ?1] [?1 ->
    if item ?1 playerTeams = teamID [
      set currentActionList (map + currentActionList (item ?1 playerActions))
    ]
  ]
  foreach n-values (length currentActionList) [?1 -> ?1] [ ?1 ->
    if (item ?1 currentActionList > 0)  [
      set currentItemList lput ?1 currentItemList
      set currentCountList lput (item ?1 currentActionList) currentCountList
    ]
  ]

  let currentItems length currentItemList

  ;; build badges for player's own farm badge list

  ;;estimate the size and positioning of each one
  let availSpace 2
  let panelSpacing 0
  if currentItems > 1 [
    set panelSpacing availSpace / (currentItems - 1)
  ]

  let startX  (0.25) + offsetX

 ; let tempSize panel_selection_rel_size * patches_panel
  ;;add them all in, making them visible only to current player
  foreach n-values currentItems [?1 -> ?1 ] [ ?1 ->
    create-player-actions 1 [
      setxy (startX + ?1 * panelSpacing) patches_game * 0.85
      let tempShape [];
      ask one-of actions with [ID = (item ?1 currentItemList) + 1] [set tempShape action_name] ;;weird workaround to access the shape name
      set shape tempShape
      set size player_actions_size

      set ID teamName

      integer-as-agents (item ?1 currentCountList) 0.3 white (startX + ?1 * panelSpacing + (player_actions_size * 0.45)) (patches_game * 0.85 - player_actions_size * 0.45) (n-values numPlayers [ i -> i ]) teamName
    ]
  ]


  ;;calculate their cumulative water demand and show it
  let full_demand n-values length [demand] of one-of actions [0]

  (foreach currentItemList currentCountList [ [?1 ?2] ->
    let currentDemand [demand] of one-of actions with [ID = (?1 + 1)]
    set currentDemand map [ i -> i * ?2 ] currentDemand
    set full_demand (map + full_demand currentDemand)

  ])

  set teamDemand replace-item teamID teamDemand full_demand

  ask one-of turtles [draw-bar-chart (0 + offsetX) (patches_game * 0.6) 3 2 0.25 100 blue full_demand (n-values numPlayers [ i -> i ]) teamName true]

end

to update-player-actions [playerNumber]
  ;;update the array of  actions taken in the player panel



  ;;kill whatever was there before
  ask player-actions with [visibleTo = playerNumber and ID = "player_actions" ] [die]

  ask integer-agents with [member? playerNumber visibleTo  and ID = "player-action"] [die]
  ask integer-agents with [member? playerNumber visibleTo  and ID = "full_demand"] [die]
  ask barSquares with [member? playerNumber visibleTo  and ID = "full_demand"] [die]
  ask integer-agents with [member? playerNumber visibleTo  and ID = "resource"] [die]

  ;;;;;;;;;;;;;;;;;;;;;
  ;;count how many unique actions there are for badges
  let currentItemList (list)
  let currentCountList (list)
  let currentActionList (item playerNumber playerActions)
  foreach n-values (length currentActionList) [?1 -> ?1] [ ?1 ->
    if (item ?1 currentActionList > 0)  [
      set currentItemList lput ?1 currentItemList
      set currentCountList lput (item ?1 currentActionList) currentCountList
    ]
  ]

  let currentItems length currentItemList

  ;; build badges for player's own farm badge list

  ;;estimate the size and positioning of each one
  let availSpace 2
  let panelSpacing 0
  if currentItems > 1 [
    set panelSpacing availSpace / (currentItems - 1)
  ]

  let startX  (- patches_panel )

 ; let tempSize panel_selection_rel_size * patches_panel
  ;;add them all in, making them visible only to current player
  foreach n-values currentItems [?1 -> ?1 ] [ ?1 ->
    create-player-actions 1 [
      setxy (startX + ?1 * panelSpacing) player_actions_y
      let tempShape [];
      ask one-of actions with [ID = (item ?1 currentItemList) + 1] [set tempShape action_name] ;;weird workaround to access the shape name
      set shape tempShape
      set size player_actions_size
      set visibleTo playerNumber
      set ID "player_actions"
      foreach n-values (numPlayers) [?2 -> ?2 ] [ ?2 ->
        if ?2 != playerNumber [
         hubnet-send-override  (item (?2) playerNames) self "shape" ["blank"]
        ]
      ]
      integer-as-agents (item ?1 currentCountList) 0.3 white (startX + ?1 * panelSpacing + (player_actions_size * 0.45)) (player_actions_y - player_actions_size * 0.45) (list playerNumber) "player-action"
    ]
  ]


  ;;calculate their cumulative water demand and show it
  let full_demand n-values length [demand] of one-of actions [0]

  (foreach currentItemList currentCountList [ [?1 ?2] ->
    let currentDemand [demand] of one-of actions with [ID = (?1 + 1)]
    set currentDemand map [ i -> i * ?2 ] currentDemand
    set full_demand (map + full_demand currentDemand)

  ])

  set playerDemand replace-item playerNumber playerDemand full_demand

  ask one-of turtles [draw-bar-chart (- patches_panel + 1) (- 0.3) 1.5 1 0.1 40 blue full_demand (list playerNumber) "full_demand" true]

    integer-as-agents (item playerNumber playerResources) 1 green (- patches_panel * 0.4) (patches_panel * 0.02) (list playerNumber) "resource"

end

to listen

  ;; this is the main message processing procedure for the game.  this procedure responds to hubnet messages, one at a time, as long as the 'Listen Clients' button is down
  ;; where appropriate, this procedure can be made easier to read by exporting the response to the message case to its own procedure

  ;; while there are messages to be processed
  while [hubnet-message-waiting?] [

    ;; we use a 'message addressed' flag to avoid having to nest foreach loops (there is no switch/case structure in netlogo)
    ;; the procedure steps through each case from top to bottom until it finds criteria that fit.  it then executes that code and marks the message addressed
    ;; it is CRITICAL that you order the cases correctly - from MOST SPECIFIC to LEAST SPECIFIC - if there is any ambiguity in interpreting the message
    ;; e.g., where you have a button or other feature that sits within a larger clickable area, list the case for the button first, then the larger area surrounding it
    set messageAddressed 0

    ;; get the next message in the queue
    hubnet-fetch-message



    ;; CASE 1 and CASE 2 messages are responses to messages of players coming in and out of the game.  hopefully, what's there is a good fit to your purpose

    ;; CASE 3  are responses to a click/tap from a player.

    ;; CASE 4  are 'mouse up' responses after clicking, which at present we are not using.  these are helpful to make use of 'mouse drag' actions

    ;; CASE 5  are otherwise unhandled messages

    ;; CASE 1 if the message is that someone has entered the game
    if (hubnet-enter-message? and messageAddressed = 0)[

      ;; CASE 1.1 if the player has already been in the game, link them back in.  if the player is new, set them up to join
      ifelse (member? hubnet-message-source playerNames ) [

        ;; pre-existing player whose connection cut out
        let newMessage word hubnet-message-source " is back."
        hubnet-broadcast-message newMessage

        ;; give the player the current game information
        let currentMessagePosition (position hubnet-message-source playerNames);
        let currentPlayer currentMessagePosition + 1
        send-game-info currentMessagePosition

      ] ;; end previous player re-entering code

      [ ;; CASE 1.2 otherwise it's a new player trying to join

        ;; new players can only get registered if a game isn't underway
        if (gameInProgress = 0) [  ;;only let people join if we are between games


          ;; register the player name
          set playerNames lput hubnet-message-source playerNames


          ;; add the new player, and give them a color
            set numPlayers numPlayers + 1
          set playerPosition lput numPlayers playerPosition
          set playerColor lput (item (numPlayers - 1) colorList) playerColor

          ;; let everyone know
          let newMessage word hubnet-message-source " has joined the game."
          hubnet-broadcast-message newMessage
          ;file-print (word hubnet-message-source " has joined the game as Player " numPlayers " at " date-and-time)

        ]  ;; end new player code
      ] ;; end ifelse CASE 1.1 / CASE 1.2

      ;; mark this message as done
      set messageAddressed 1
    ] ;; end CASE 1

    ;; CASE 2 if the message is that someone left
    if (hubnet-exit-message? and messageAddressed = 0)[

      ;; nothing to do but let people know
      let newMessage word hubnet-message-source " has left.  Waiting."
      hubnet-broadcast-message newMessage

      ;; mark the message done
      set messageAddressed 1
    ] ;; end CASE 2

    ;;CASE 3 the remaining cases are messages that something has been tapped, which are only processed if 1) a game is underway, 2) the message hasn't been addressed earlier, and 3) the player is in the game
    if (gameInProgress = 1 and messageAddressed = 0 and (member? hubnet-message-source playerNames))[

      ;; identify the sender
      let currentMessagePosition (position hubnet-message-source playerNames);  ;;who the message is coming from, indexed from 0
      let currentPlayer (currentMessagePosition + 1); ;;who the player is, indexed from 1

      if (hubnet-message-tag = "View" )  [  ;; the current player tapped something in the view


        ;;identify the patch
        let xPatch (item 0 hubnet-message)
        let yPatch (item 1 hubnet-message)
        let xPixel (xPatch - min-pxcor + 0.5) * patch-size
        let yPixel (max-pycor + 0.5 - yPatch) * patch-size

        let currentPXCor [pxcor] of patch xPatch yPatch
        let currentPYCor [pycor] of patch xPatch yPatch

        let patchInGame [inGame?] of patch xPatch yPatch
        let notConfirmed? (item (currentPlayer - 1) playerConfirm = 0)

        ;; CASE 3.1 if the tap is on the confirm button
        if ( clicked-area confirm_area and messageAddressed = 0)[

          ;; mark the confirm and record
          let newMessage word (item (currentPlayer - 1) playerNames) " clicked confirm."
          hubnet-broadcast-message newMessage
          output-print newMessage
          file-print (word "Case 3.1 - Player " currentPlayer " clicked confirm button at " date-and-time)

          if (notConfirmed?) [;; hasn't already confirmed
            confirm-actions currentPlayer
          ]
          ;; mark message done
          set messageAddressed 1
        ] ;; end 3.1

       ;; CASE 3.2 if the tap is on a plus sign
        if messageAddressed = 0 and item (currentPlayer - 1) playerConfirm = 0 [
          ask plusses with [hidden? = false and item currentMessagePosition visibleTo = 1] [
           let plusLoc (list (xcor - size / 2) (ycor - size / 2) size size)
          if clicked-area ( plusLoc) [


              ;; mark the confirm and record
              let newMessage word (item (currentPlayer - 1) playerNames) " clicked a plus."
              hubnet-broadcast-message newMessage
              output-print newMessage
              file-print (word "Case 3.2 - Player " currentPlayer " clicked a plus at " date-and-time)

              plus-activity currentMessagePosition



              ;; mark message done
              set messageAddressed 1
            ]

          ]
          update-current-selections currentMessagePosition


        ] ;; end 3.2


        ;; CASE 3.3 if the tap is on a minus sign
        if messageAddressed = 0 and item (currentPlayer - 1) playerConfirm = 0 [
         ask minuses with [hidden? = false and item currentMessagePosition visibleTo = 1][
            let minusLoc (list (xcor - size / 2) (ycor - size / 2) size size)

            if clicked-area ( minusLoc) [

              ;; mark the confirm and record
              let newMessage word (item (currentPlayer - 1) playerNames) " clicked a minus."
              hubnet-broadcast-message newMessage
              output-print newMessage
              file-print (word "Case 3.3 - Player " currentPlayer " clicked a minus at " date-and-time)

              minus-activity currentMessagePosition


              ;; mark message done
              set messageAddressed 1

            ]

          ]
          update-current-selections currentMessagePosition


        ] ;; end 3.3


        ;; CASE 3.4 if the tap is on an arrow
        if messageAddressed = 0 and item (currentPlayer - 1) playerConfirm = 0 [
          ask arrows with [hidden? = false][
            let arrowLoc (list (xcor - size / 2) (ycor - size / 2) size size)

            if clicked-area ( arrowLoc) [

              ;; mark the confirm and record
              let newMessage word (item (currentPlayer - 1) playerNames) " clicked an arrow."
              hubnet-broadcast-message newMessage
              output-print newMessage
              file-print (word "Case 3.3 - Player " currentPlayer " clicked an arrow at " date-and-time)

              ;; mark message done
              set messageAddressed 1
              arrow-activity currentMessagePosition identity (item (currentMessagePosition) menu)

            ]

          ]
        ] ;; end 3.4

        ;; CASE 3.5 if the tap is on a gate button
        if messageAddressed = 0 and item (currentPlayer - 1) playerConfirm = 0 [
          ask buttons with [identity = "gate_setting"][
            let gateButtonLoc (list (xcor - size / 2) (ycor - size / 2) size size)

            if clicked-area ( gateButtonLoc) [

              ;; mark the confirm and record
              let newMessage word (item (currentPlayer - 1) playerNames) " clicked a gate button."
              hubnet-broadcast-message newMessage
              output-print newMessage
              file-print (word "Case 3.5 - Player " currentPlayer " clicked a gate button at " date-and-time)

              ;; mark message done
              set messageAddressed 1

              ;;do whatever has to be done
              update-gate-choice (currentPlayer - 1)

            ]

          ]
        ] ;; end 3.4


      ] ;; end all cases for clicks within the  "view"


    ] ;; end all CASE 3 messages

    ;; CASE 4 - Mouse up after a click message
    if (gameInProgress = 1 and messageAddressed = 0 and hubnet-message-tag = "Mouse Up") [

     ;; no need to do anything
     set messageAddressed 1
    ]

    if (gameInProgress = 1 and messageAddressed = 0) [
      ;; CASE 5 if the message still hasn't been addressed, it means players clicked in a place that they weren't meant to - ignore it
      set messageAddressed 1
      output-print "Unhandled message"

    ]
  ]


end

to update-gate-choice [currentPosition] ;;currentPosition is 0-indexed

  ask buttons with [identity = "gate_setting"] [hubnet-clear-override  (item currentPosition playerNames) self "color" ]
  hubnet-send-override  (item currentPosition playerNames) self "color" [red]

  set playerGateChoice replace-item currentPosition playerGateChoice value

end

to plus-action [currentMessagePosition]

  let myAction item currentMessagePosition showing
  let currentMax [amt_max] of one-of actions with [ID = myAction]



  ;;allow for possibility that max values are specified not as numbers but as other variables
  set tempLocal currentMessagePosition

  if is-string? currentMax [ run (word "set tempLocal " currentMax)

    set currentMax tempLocal]



  let currentCost [cost] of one-of actions with [ID = myAction]

  ;; if we can add more of the current action, do
  let currentCount item (myAction - 1) (item currentMessagePosition playerCurrentSelections)
  let potentialCost item currentMessagePosition playerCurrentResources + currentCost
  let budget item currentMessagePosition playerResources


  if (currentCount < currentMax and potentialCost <= budget and tempLocal > 0) [
    set currentCount currentCount + 1
    set playerCurrentSelections (replace-item currentMessagePosition playerCurrentSelections (replace-item (myAction - 1) (item currentMessagePosition playerCurrentSelections) (currentCount)))


  ]

  update-current-selections currentMessagePosition
  update-colors myAction currentMessagePosition


end

to minus-action [currentMessagePosition]

 let myAction item currentMessagePosition showing
  let currentMin [amt_min] of one-of actions with [ID = myAction]
  let currentCost [cost] of one-of actions with [ID = myAction]



  ;; if we can subtract more of the current action, do
  let currentCount item (myAction - 1) (item currentMessagePosition playerCurrentSelections)
  let potentialCost item currentMessagePosition playerCurrentResources - currentCost
  let budget item currentMessagePosition playerResources
  if (currentCount > currentMin and potentialCost <= budget) [
    set currentCount currentCount - 1
    set playerCurrentSelections (replace-item currentMessagePosition playerCurrentSelections (replace-item (myAction - 1) (item currentMessagePosition playerCurrentSelections) (currentCount)))



  ]

  update-current-selections currentMessagePosition
  update-colors myAction currentMessagePosition

end

to update-current-selections [playerNumber]
    ;;update the array of currently selected activities in the player panel

  ;;kill whatever was there before
  ask integer-agents with [member? playerNumber visibleTo and ID = "currentResource"] [die]

  ;;count how many unique activities there are
  let currentItemList (list)
  let currentCountList (list)
  let currentCostList (list)
  let currentBenefitList (list)
  let currentSelectionList (item playerNumber playerCurrentSelections)
  foreach n-values (length currentSelectionList) [?1 -> ?1] [ ?1 ->
    if item ?1 currentSelectionList > 0 [
      set currentItemList lput ?1 currentItemList
      set currentCountList lput (item ?1 currentSelectionList) currentCountList
      set currentCostList lput ((item ?1 actionCostList) * (item ?1 currentSelectionList)) currentCostList
      set currentBenefitList lput ((item ?1 actionBenefitList) * (item ?1 currentSelectionList)) currentBenefitList
    ]
  ]

  ;ask actions that are currently being shown to post a number of their count, next to the action in panel


  set playerCurrentResources replace-item playerNumber playerCurrentResources  (sum currentCostList)

  ;;
  integer-as-agents (item playerNumber playerCurrentResources) 1 red (- patches_panel * 0.4) (patches_panel * 0.2) (list playerNumber) "currentResource"

end

to send-game-info [currentPosition]

  ;; sends current, player-specific game info to the specified player.  this is useful if the player has left the game and returned, so that any view overrides are re-established.
  ;;example:  ask dayBoxes [hubnet-send-override (item currentPosition playerNames) self "hidden?" [true]]

  show currentPosition
  update-current-selections currentPosition
  update-player-actions currentPosition
  update-displayed-actions currentPosition

  if-else item currentPosition playerTeams = 0 [ ;;upstream team
    ask buttons with [identity = "team2"] [hubnet-send-override (item currentPosition playerNames) self "shape" ["square outline"]]
  ] [
    ask buttons with [identity = "team1"] [hubnet-send-override (item currentPosition playerNames) self "shape" ["square outline"]]
  ]

  ask integer-agents [
    if (not member? currentPosition visibleTo) [
      hubnet-send-override  (item currentPosition playerNames) self "shape" ["blank"]
    ]
  ]

  ask barSquares [
    if (not member? currentPosition visibleTo) [
      hubnet-send-override  (item currentPosition playerNames) self "shape" ["blank"]
    ]
  ]


  ask buttons with [identity = "confirm"]  [
    if item currentPosition playerConfirm = 1 [
      hubnet-send-override (item currentPosition playerNames) self "color" [confirm-down-color]
    ]

  ]


  if-else currentPhase > 0 [
    ask buttons with [identity = "gate_setting"][set hidden? false]
    ask integer-agents with [ID = "gate_setting"][set hidden? false]

    ask turtles with [xcor < 0 and ycor > border_player_summary and ycor < border_actions + 0.5] [set hidden? true]


  ][
    ask buttons with [identity = "gate_setting"][set hidden? true]
    ask integer-agents with [ID = "gate_setting"][set hidden? true]

    ask turtles with [xcor < 0 and ycor > border_player_summary and ycor < border_actions + 0.5] [set hidden? false]

  ]

end

to update-gate-level

  let meanGate mean playerGateChoice
  let diffGate map [i -> abs (i - meanGate)] gate_settings
  let gateChoice item (position (min diffGate) diffGate) gate_settings


  set downstream_share (gateChoice / 100)

  foreach playerPosition [ ?1 ->
    ask buttons with [identity = "gate_setting"] [hubnet-clear-override  (item (position ?1 playerPosition) playerNames) self "color" ]
    ask buttons with [identity = "gate_setting" and value = gateChoice] [hubnet-send-override  (item (position ?1 playerPosition) playerNames) self "color" [blue] ]
  ] ;; end foreach player

  set playerGateChoice n-values numPlayers [0]


end

to advance-to-next-round


  ;;;;;;calculate changes across last round


  if currentPhase = phasesPerRound [ ;; we have finished all the water stages for a round and are getting yields / expirations of products

    ;;;;;;;step through all of players' selections and update their points/farms as necessary
    foreach n-values numPlayers [?1 -> ?1] [?1 ->

      ;;calculate the yields from anything that was provided through this round, scaled by damages
      let currentPoints 0
      if  (sum item (item ?1 playerTeams) teamDemand) > 0 [
        let demandFraction (sum item (item ?1 playerTeams) teamReceipt) / (sum item (item ?1 playerTeams) teamDemand)
        set currentPoints (round demandFraction * (sum (map * (item ?1 playerActions) (map [?t -> [benefit] of ?t] sort-on [ID] actions ))))
      ]

      ;; for each player, make a list of the current actions they're doing (broken out by duration) and the new things they're adding
      let currentDurations (item ?1 playerActionsDuration)

      let currentCounter 0
      foreach currentDurations [?2 ->   ;; foreach of these different actions
        let tempActions map [i -> i - 1] ?2 ;;decrement the age by one
        set tempActions remove 0 tempActions ;; remove those that are worn out to 0

        set currentDurations replace-item currentCounter currentDurations tempActions ;;store this new count in the full list for the player
        set currentCounter currentCounter + 1
      ]
      set playerActionsDuration replace-item ?1 playerActionsDuration currentDurations  ;;store the player list in the full list
      set playerActions replace-item ?1 playerActions map [i -> length i] currentDurations  ;; calculate the total number of each actions for the player, and store it in the full list


      set playerResources replace-item ?1 playerResources ((item ?1 playerResources) + currentPoints + endowment)

      update-current-selections (?1)
      update-player-actions (?1)

    ]

    update-team-actions 0 "upstream" 0
    update-team-actions 1 "downstream" 3.5

    ;foreach playerPosition [ ?1 ->
    ;  update-player-actions (?1 - 1)
    ;]

  ]

  if currentPhase = 0 [ ;; we are finishing the phase of new selections, to be processed

    ;;;;;;;step through all of players' selections and update their points/farms as necessary
    foreach n-values numPlayers [?1 -> ?1] [?1 ->



      ;; for each player, make a list of the new things they're adding
      let currentDurations (item ?1 playerActionsDuration)
      let currentNewSelections (item ?1 playerCurrentSelections)
      let currentCounter 0
      foreach currentDurations [?2 ->   ;; foreach of these different actions
        let tempActions ?2 ;;decrement the age by one
        set tempActions sentence tempActions n-values (item currentCounter currentNewSelections) [[duration] of one-of actions with [ID = currentCounter + 1]] ;; add on new ones with their full duration
        set currentDurations replace-item currentCounter currentDurations tempActions ;;store this new count in the full list for the player
        set currentCounter currentCounter + 1
      ]
      set playerActionsDuration replace-item ?1 playerActionsDuration currentDurations  ;;store the player list in the full list
      set playerActions replace-item ?1 playerActions map [i -> length i] currentDurations  ;; calculate the total number of each actions for the player, and store it in the full list

      set playerCurrentSelections replace-item ?1 playerCurrentSelections (n-values (count actions) [0])

      set playerResources replace-item ?1 playerResources ((item ?1 playerResources) - item ?1 playerCurrentResources)
      set playerCurrentResources replace-item ?1 playerCurrentResources [0]

      update-current-selections (?1)
      update-player-actions (?1)

    ]

    update-team-actions 0 "upstream" 0
    update-team-actions 1 "downstream" 3.5

    ;foreach playerPosition [ ?1 ->
    ;  update-player-actions (?1 - 1)
    ;]

  ]


  ;;;;If we're anywhere other than phase 0 (i.e., in a water gate phase, update water supply

  if currentPhase > 0 [

    ;;identify how open the gate will be, in any phase OTHER than when we are leading in
    update-gate-level

    ask integer-agents with [member? "_supply" ID] [die]
    let currentUpstreamSupply item (currentPhase - 1) item (currentRound - 1) upstreamWaterSupply
    let currentDownstreamSupply item (currentPhase - 1) item (currentRound - 1) downstreamWaterSupply

    ;;natural flows, including gate
    set upstreamVolume upstreamVolume + currentUpstreamSupply
    let downstream_flow downstream_share * upstreamVolume
    set upstreamVolume upstreamVolume - downstream_flow
    set downstreamVolume downstreamVolume + downstream_flow - downstream_drainage * downstreamVolume + currentDownstreamSupply

    ;;abstractions by demand
    let upstreamCurrentPhaseReceipt (min list (item (currentPhase - 1) item 0 teamDemand) upstreamVolume)  ;;find out total abstracted
    let currentRoundReceipt item (currentRound - 1) upstreamWaterReceipt ;; get list of upstream water receipt values for this round
    set currentRoundReceipt replace-item (currentPhase - 1) currentRoundReceipt upstreamCurrentPhaseReceipt ;; update this list with current phase
    set upstreamWaterReceipt replace-item (currentRound - 1) upstreamWaterReceipt currentRoundReceipt ;; add it to our full record of receipt
    set teamReceipt replace-item 0 teamReceipt currentRoundReceipt ;; add it to our current record of receipt (for visualization)
    set upstreamVolume upstreamVolume - upstreamCurrentPhaseReceipt ;; reduce current volume by abstraction

    let downstreamCurrentPhaseReceipt (min list (item (currentPhase - 1) item 1 teamDemand) downstreamVolume)  ;;find out total abstracted
    set currentRoundReceipt item (currentRound - 1) downstreamWaterReceipt ;; get list of upstream water receipt values for this round
    set currentRoundReceipt replace-item (currentPhase - 1) currentRoundReceipt downstreamCurrentPhaseReceipt ;; update this list with current phase
    set downstreamWaterReceipt replace-item (currentRound - 1) downstreamWaterReceipt currentRoundReceipt ;; add it to our full record of receipt
    set teamReceipt replace-item 1 teamReceipt currentRoundReceipt ;; add it to our current record of receipt (for visualization)
    set downstreamVolume downstreamVolume - downstreamCurrentPhaseReceipt ;; reduce current volume by abstraction

    draw-baths
    integer-as-agents currentUpstreamSupply 0.5 white 1 3 (n-values numPlayers [?1 -> ?1]) "upstream_supply"
    integer-as-agents currentDownstreamSupply 0.5 white 4.75 2 (n-values numPlayers [?1 -> ?1]) "downstream_supply"
  ]


    ;;;;;;;update any visuals that still need updating

  ;;update plots
  update-plots
  ask barSquares with [member? "_receipt" ID] [die]
  ask one-of turtles [draw-bar-chart (0) (patches_game * 0.6) 3 2 0.25 100 98 (item 0 teamReceipt) (n-values numPlayers [ i -> i ]) "upstream_receipt" false]
  ask one-of turtles [draw-bar-chart (3.5) (patches_game * 0.6) 3 2 0.25 100 98 (item 1 teamReceipt) (n-values numPlayers [ i -> i ]) "downstream_receipt" false]



  ;;;;;;update the round/phase clock
  ask integer-agents with [ID = "round"] [die]
  ask integer-agents with [ID = "phase"] [die]

  ;;make a round counter visible to all

  if-else currentPhase < phasesPerRound [
    set currentPhase currentPhase + 1
    integer-as-agents currentRound 1 red (- 4.5) 5.7 (n-values numPlayers [?1 -> ?1]) "round"
    integer-as-agents currentPhase 0.5 blue (- 4) 5.5 (n-values numPlayers [?1 -> ?1]) "phase"
  ][
   if-else currentRound < numRounds [
      set currentPhase 0
      set currentRound currentRound + 1
      integer-as-agents currentRound 1 red (- 4.5) 5.7 (n-values numPlayers [?1 -> ?1]) "round"
      integer-as-agents currentPhase 0.5 blue (- 4) 5.5 (n-values numPlayers [?1 -> ?1]) "phase"

      set teamReceipt n-values 2 [n-values phasesPerRound [0]]
    ][
      end-game
      stop
    ]
  ]

  if-else currentPhase > 0 [
    ask buttons with [identity = "gate_setting"][set hidden? false]
    ask integer-agents with [ID = "gate_setting"][set hidden? false]

    ask turtles with [xcor < 0 and ycor > border_player_summary and ycor < border_actions + 0.5] [set hidden? true]


  ][
    ask buttons with [identity = "gate_setting"][set hidden? true]
    ask integer-agents with [ID = "gate_setting"][set hidden? true]

    ask turtles with [xcor < 0 and ycor > border_player_summary and ycor < border_actions + 0.5] [set hidden? false]

  ]

  ;;;;;; As a last step before going back to players, reset player confirm buttons and appearance
  foreach playerPosition [ ?1 ->
    ask buttons with [identity = "confirm"] [hubnet-clear-override  (item (position ?1 playerPosition) playerNames) self "color" ]
  ] ;; end foreach player
  set playerConfirm n-values numPlayers [0]


end

to integer-as-agents [intI sizeI colI posX posY seen_by name]

  let strI (word intI)
  let offset 0
  while [length strI > 0] [
   let currentI first strI
    ask one-of patches [  ;; a little hack to make this procedure usable both in observer and turtle context - ask a patch to do it.
      sprout-integer-agents 1 [
        set visibleTo (list)
        setxy  posX + offset posY
        set size sizeI
        if-else currentI = "-" [
          set shape "num-minus"
        ][
          set shape item (read-from-string currentI) number_shape_list]
        set color colI
        set ID name


        foreach n-values (numPlayers) [?2 -> ?2 ] [ ?2 ->

          if-else (member? ?2 seen_by) [
            set visibleTo lput ?2 visibleTo
          ] [
            hubnet-send-override  (item (?2) playerNames) self "shape" ["blank"]
          ]
        ]


      ]

    ]
    set strI but-first strI

    set offset offset + sizeI * 0.5
  ]


end

to draw-baths

  let currentUpstreamVolume (min list round(upstreamVolume) upstream_basin_max)
  let currentDownstreamVolume (min list round(downstreamVolume) downstream_basin_max)

  let upstream_color blue
  if round(upstreamVolume) > currentUpstreamVolume [
    set upstream_color red
  ]

  let downstream_color blue
  if round(downstreamVolume) > currentDownstreamVolume [
    set downstream_color red
  ]

  ask barSquares with [member? "volume" ID] [die]
  ask integer-agents with [member? "volume" ID] [die]
  ask one-of turtles [
    draw-bar-chart upstreamX upstreamY upstreamW upstreamH 0 upstream_basin_max upstream_color (list currentUpstreamVolume) (n-values numPlayers [ i -> i ])  "upstream_volume" false
    draw-bar-chart downstreamX downstreamY downstreamW downstreamH 0 downstream_basin_max downstream_color (list currentDownstreamVolume) (n-values numPlayers [ i -> i ])  "downstream_volume" false
  ]
  integer-as-agents round(upstreamVolume) 1 white 1 1.25 (n-values numPlayers [?1 -> ?1]) "upstream_volume"
  integer-as-agents round(downstreamVolume) 1 white 4.5 0.25 (n-values numPlayers [?1 -> ?1]) "downstream_volume"

end

to make-shared-borders
    ;; make border around areas used by one player
  ;; do this using 'border' agents that stamp an image of themselves between patches and then die
  ;; note:  if you have wraparound, the setxy line has to be modified to account for this

  ask patches with [inGame?] [
    let x1 pxcor
    let y1 pycor
    let currentAccess item 0 playerAccess
    if currentAccess > 0 [
      let currentColor item ((item 0 playerAccess) - 1) colorList

      ask neighbors4 [
        let x2 pxcor
        let y2 pycor
        let neighborAccess item 0 playerAccess

        if currentAccess != neighborAccess  [
          sprout-borders 1 [set color currentColor
            set shape "line-thick"
            setxy mean (list x1 x2) mean (list y1 y2)
            (ifelse
              y1 < y2 [set heading 270]
              y1 > y2 [set heading 90]
              x1 < x2 [set heading 0]
              x1 > x2 [set heading 180]
              )
            stamp die]


        ]
    ]]

  ]

end

to update-colors [currentCounter playerNumber]

  let currentCount item (currentCounter - 1) (item playerNumber playerCurrentSelections)
  let currentMax [amt_max] of one-of actions with [ID = currentCounter]
  let currentMin [amt_min] of one-of actions with [ID = currentCounter]

  ;if not is-number? amt_max run (word "set amt_max " amt_max
  set tempLocal playerNumber

  if is-string? currentMax [ run (word "set tempLocal " currentMax)

    set currentMax tempLocal]

  ask plusses with [item playerNumber showing = currentCounter] [
    if-else currentCount = currentMax [
      ;; code to gray out and disable plus sign
      hubnet-send-override (item (playerNumber) playerNames) self "color" [gray]
    ] [
      hubnet-send-override (item (playerNumber) playerNames) self "color" [blue]
    ]
  ]

  ask minuses with [item playerNumber showing = currentCounter] [
    if-else currentCount = currentMin [
      ;; code to gray out and disable plus sign
      hubnet-send-override (item (playerNumber) playerNames) self "color" [gray]

    ] [
      hubnet-send-override (item (playerNumber) playerNames) self "color" [blue]

    ]
  ]

end

to make-borders
    ;; make border around pasture parcels
  ;; do this using 'border' agents that stamp an image of themselves between patches and then die
  ;; note:  if you have wraparound, the setxy line has to be modified to account for this


  ask patches with [pxcor = 0 ] [
    sprout-borders 1 [set color red
      setxy pxcor - 0.5 pycor
      set heading 0
      stamp die]
  ]

  ask patches with [pxcor < 0 and pycor = border_player_summary] [
    sprout-borders 1 [set color red
      setxy pxcor pycor + 0.5
      set heading 90
      stamp die]
  ]

  ask patches with [pxcor < 0 and pycor = border_actions] [
    sprout-borders 1 [set color red
      setxy pxcor pycor + 0.5
      set heading 90
      stamp die]
  ]

  ask patches with [pxcor = floor (patches_game / 2) ] [
    sprout-borders 1 [set color blue
      setxy pxcor pycor
      set heading 0
      stamp die]
  ]

end

to confirm-actions [currentPlayer]

  set playerConfirm replace-item (currentPlayer - 1) playerConfirm 1
  ask buttons with [identity = "confirm"] [hubnet-send-override (item (position currentPlayer playerPosition) playerNames) self "color" [confirm-down-color]]


  if sum playerConfirm = numPlayers [ ;; all players are confirmed, round is over, do end-of-round things
    advance-to-next-round
  ]

end

to-report clicked-area [ current_area ]

  ;; checks the boundaries of a click message against those of a 'button' to see if it was the one clicked

  let xPatch (item 0 hubnet-message)
  let yPatch  (item 1 hubnet-message)
  let xMin item 0 current_area
  let xMax item 0 current_area + item 2 current_area
  let yMin item 1 current_area
  let yMax item 1 current_area + item 3 current_area
  ifelse xPatch > xMin and xPatch < xMax and yPatch > yMin and yPatch < yMax [  ;; player "clicked"  the current button
    report true
  ] [
    report false
  ]

end

to end-game


  set gameInProgress 0

  ;;do anything else that ought to be done to finalize game files, etc.
end
@#$#@#$#@
GRAPHICS-WINDOW
279
10
1367
649
-1
-1
90.0
1
50
1
1
1
0
0
0
1
-5
6
0
6
0
0
0
ticks
30.0

BUTTON
27
434
174
467
Launch Next Game
start-game
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
122
82
263
115
Launch Broadcast
start-hubnet
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
28
388
159
421
Listen to Clients
listen
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

OUTPUT
10
484
250
742
13

INPUTBOX
35
12
264
72
inputParameterFileName
sessionList.csv
1
0
String

BUTTON
128
212
261
245
Initialize Session
initialize-session
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
114
133
263
193
sessionID
101.0
1
0
Number

@#$#@#$#@
## WHAT IS IT?

This is a basic template for using HubNet in NetLogo to develop multiplayer games.  It includes some of the most basic elements - procedures to run a game, and to listen for / handle HubNet messages.

It also includes a few bits of sample code for key features of a game:

> marking some parts of the view as 'in the game' and other parts as part of the display

> allowing players to manipulate the game surface in a way that is seen by other players, either by changing patch colors or by changing turtle shapes

> having game elements that display differently on each player's screen

This template does not use any NetLogo UI elements in the HubNet client interface.  Instead, we create virtual UI elements in the 'display' portion of the view, for which we have much more visual control (colors, size, etc.)

## HOW IT WORKS

Specific actions in this game template

> Tap on a red square to turn it green, and observe your 'turned green' counter go up

> Tap on a green square to turn it red, and observe your 'turned red' counter go down

> Tap on the 'confirm' button and see the record of it being clicked appear in the host's output monitor


## START-UP INSTRUCTIONS

> 1. Log all of your tablets onto the same network.  If you are in the field using a portable router, this is likely to be the only available wifi network.

> 2. Open the game file on your host tablet.  Zoom out until it fits in your screen

> 3. If necessary, change the language setting on the host.

> 4. Click ‘Launch Broadcast’.  This will reset the software, as well as read in the file containing all game settings.

> 5. Select ‘Mirror 2D view on clients’ on the Hubnet Control Center.

> 6. Click ‘Listen Clients’ on the main screen.  This tells your tablet to listen for the actions of the client computers.  If there ever are any errors generated by Netlogo, this will turn off.  Make sure you turn it back on after clearing the error.

> 7. Open Hubnet on all of the client computers.  Enter the player names in the client computers, in the form ‘PlayerName_HHID’.

> 8. If the game being broadcast shows up in the list, select it.  Otherwise, manually type in the server address (shown in ‘Hubnet Control Center’).

> 9. Click ‘Enter’ on each client.

> 10. Click 'Launch Next Game' to start game.

** A small bug – once you start *EACH* new game, you must have one client exit and re-enter.  For some reason the image files do not load initially, but will load on all client computers once a player has exited and re-entered.  I believe this is something to do with an imperfect match between the world size and the client window size, which auto-corrects on re-entry.  Be sure not to change the player name or number when they re-enter.


## NETLOGO FEATURES

This template exploits the use of the bitmap extension, agent labeling, and hubnet overrides to get around the limitations of NetLogo's visualization capacities.

In the hubnet client, all actual buttons are avoided.  Instead, the world is extended, with patches to the right of the origin capturing elements of the game play, and patches to the left of the origin being used only to display game messages.

Language support is achieved by porting all in-game text to bitmap images that are loaded into the view.

## THINGS TO TRY

This template is meant as a starting point for the development of a dynamic game.  A few of the first things you might try, as exercises to get comfortable with the interface, are:

> Add 'turns'

>> Add a global variable that records whether players have clicked 'Confirm'

>> Adjust the 'Listen' procedure so that once a player clicks 'Confirm', they can't change squares betwen red and green anymore

>> Add a procedure to be run when all players have clicked 'Confirm' - maybe it sends a message to all players, maybe it changes all the colors to something new, maybe it's some cool thing I can't even imagine

>> Within the procedure above, reset the global variable that records 'Confirm' clicks so that players can play again.  Make sure that this procedure is called within the 'Listen' procedure

> Add 'ownership'

>> Add a property to patches that records which player turns them green

>> Adjust the update-patch-state procedure to only change back from green to red, if they were clicked on by the same player who turned them green to begin with

>> Adjust your 'end of turn' procedure to be triggered either by all players clicking confirm, or by all patches in the game being turned green, making each turn a sort of 'resource derby'

>> Adjust the color scheme so that instead of turning red to green, the patches clicked on by players turn from dark gray to the color assigned to that player, so that each player can see who is taking what

> Fill out the panel

>> Create counters that capture the score players accumulate from round to round, and label them (with text, pictures, whatever you think works best)

Now explore what's possible.  Are there spatial interactions that matter?  Is it better to have lots of patches together that are the same color?  Is there something different about a patch sharing a border with another?  Are there other ways that players might interact?

## CREDITS AND REFERENCES

Examples of some of the games published using this approach are:

> Bell, A. R., Rakotonarivo, O. S., Bhargava, A., Duthie, A. B., Zhang, W., Sargent, R., Lewis, A. R., & Kipchumba, A. (2023). Financial incentives often fail to reconcile agricultural productivity and pro-conservation behavior. Communications Earth and Environment, 4(2023), 27. https://doi.org/10.1038/s43247-023-00689-6

> Rakotonarivo, O. S., Bell, A., Dillon, B., Duthie, A. B., Kipchumba, A., Rasolofoson, R. A., Razafimanahaka, J., & Bunnefeld, N. (2021). Experimental Evidence on the Impact of Payments and Property Rights on Forest User Decisions. Frontiers in Conservation Science, 2(July), 1–16. https://doi.org/10.3389/fcosc.2021.661987

> Rakotonarivo, O. S., Jones, I. L., Bell, A., Duthie, A. B., Cusack, J., Minderman, J., Hogan, J., Hodgson, I., & Bunnefeld, N. (2020). Experimental evidence for conservation conflict interventions: The importance of financial payments, community trust and equity attitudes. People and Nature, August, 1–14. https://doi.org/10.1002/pan3.10155

> Rakotonarivo, S. O., Bell, A. R., Abernethy, K., Minderman, J., Bradley Duthie, A., Redpath, S., Keane, A., Travers, H., Bourgeois, S., Moukagni, L. L., Cusack, J. J., Jones, I. L., Pozo, R. A., & Bunnefeld, N. (2021). The role of incentive-based instruments and social equity in conservation conflict interventions. Ecology and Society, 26(2). https://doi.org/10.5751/ES-12306-260208

> Sargent, R., Rakotonarivo, O. S., Rushton, S. P., Cascio, B. J., Grau, A., Bell, A. R., Bunnefeld, N., Dickman, A., & Pfeifer, M. (2022). An experimental game to examine pastoralists’ preferences for human–lion coexistence strategies. People and Nature, June, 1–16. https://doi.org/10.1002/pan3.10393

> Bell, A., & Zhang, W. (2016). Payments discourage coordination in ecosystem services provision: evidence from behavioral experiments in Southeast Asia. Environmental Research Letters, 11, 114024. https://doi.org/10.1088/1748-9326/11/11/114024

> ﻿Bell, A., Zhang, W., & Nou, K. (2016). Pesticide use and cooperative management of natural enemy habitat in a framed field experiment. Agricultural Systems, 143, 1–13. https://doi.org/10.1016/j.agsy.2015.11.012
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

activity-arrow
true
0
Polygon -7500403 true true 150 0 60 150 105 150 105 293 195 293 195 150 240 150

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

badge-minus
false
9
Rectangle -11221820 true false 45 45 255 255
Polygon -13791810 true true 45 45 45 255 255 255 255 45 45 45 60 240 240 240 240 60 60 60
Polygon -13791810 true true 60 60 60 240 45 255 45 45 60 45
Polygon -13791810 true true 75 120 75 180 120 180 120 180 165 180 180 180 180 180 225 180 225 120 180 120 180 120 120 120 120 120

badge-plus
false
9
Rectangle -11221820 true false 45 45 255 255
Polygon -13791810 true true 45 45 45 255 255 255 255 45 45 45 60 240 240 240 240 60 60 60
Polygon -13791810 true true 60 60 60 240 45 255 45 45 60 45
Polygon -13791810 true true 75 120 75 180 120 180 120 225 165 225 180 225 180 180 225 180 225 120 180 120 180 75 120 75 120 120

bar
true
0
Rectangle -7500403 true true 0 0 300 30

blank
true
0

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

check
false
0
Polygon -7500403 true true 55 138 22 155 53 196 72 232 91 288 111 272 136 258 147 220 167 174 208 113 280 24 257 7 192 78 151 138 106 213 87 182

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

confirm
false
6
Rectangle -10899396 true false 0 60 300 225
Rectangle -13840069 true true 15 75 286 210
Polygon -10899396 true false 75 135 45 165 105 210 270 75 105 165

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

crook
false
0
Polygon -7500403 true true 135 285 135 90 90 60 90 30 135 0 180 15 210 60 195 75 180 30 135 15 105 30 105 60 150 75 150 285 135 285

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

hay
false
0
Polygon -1184463 true false 50 187 97 222 119 234 178 236 219 234 248 211 272 182 205 122 219 50 204 78 203 40 194 95 190 29 178 111 168 22 160 103 142 34 139 98 126 37 128 99 118 45 124 124 96 38 108 114
Polygon -6459832 true false 110 116 138 127 164 126 210 118 214 129 171 144 123 143 102 125 99 121 106 113

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

line-thick
true
0
Line -7500403 true 150 0 150 300
Rectangle -7500403 true true 135 0 150 315

num-0
false
0
Circle -7500403 true true 66 144 0
Polygon -7500403 true true 78 149 112 150 112 163 112 180
Polygon -7500403 true true 78 152 112 152 112 139 112 130 112 118 114 101 117 85 124 65 131 55 139 44 148 40 154 40 163 47 173 62 182 88 185 114 186 135 187 151 222 151 222 134 222 123 220 105 214 85 204 63 190 47 176 38 163 32 149 30 135 33 118 41 105 52 92 68 84 85 78 106 77 125 77 145 77 151
Polygon -7500403 true true 78 148 112 148 112 161 112 170 112 182 114 199 117 215 124 235 131 245 139 256 148 260 154 260 163 253 173 238 182 212 185 186 186 165 187 149 222 149 222 166 222 177 220 195 214 215 204 237 190 253 176 263 163 268 151 269 134 267 120 261 105 248 92 232 84 215 78 194 77 175 77 155 77 149

num-1
false
0
Polygon -7500403 true true 120 60 135 30 165 30 165 240 180 255 180 270 120 270 120 255 135 240 135 60

num-2
false
0
Polygon -7500403 true true 79 97 103 98 105 89 114 74 121 67 132 61 145 59 159 61 173 66 183 73 189 83 193 94 193 105 189 119 181 132 171 141 154 151 141 158 128 166 116 173 104 182 95 189 84 200 77 212 74 229 74 250 74 269 226 269 226 240 108 239 109 228 112 215 121 204 135 195 148 186 164 177 184 168 202 158 219 141 227 122 230 98 224 74 213 56 195 39 174 30 144 27 121 32 99 45 85 62 77 77 74 97 98 98

num-3
false
0
Polygon -2674135 true false 75 30
Polygon -7500403 true true 135 150 135 135 150 135 165 135 179 131 188 124 194 113 197 96 193 80 185 67 170 58 152 55 134 55 119 59 111 67 107 78 105 90 75 90 75 75 76 68 82 53 91 41 108 33 121 30 136 30 151 30 166 30 188 34 206 44 219 61 223 73 226 95 223 118 212 138 195 150 181 150 165 150 150 150
Polygon -7500403 true true 135 150 135 165 150 165 165 165 179 169 188 176 194 187 197 204 193 220 185 233 170 242 152 245 134 245 119 241 111 233 107 222 105 210 75 210 75 225 76 232 82 247 91 259 108 267 121 270 136 270 151 270 166 270 188 266 206 256 219 239 223 227 226 205 223 181 211 161 195 150 181 150 165 150 150 150

num-4
false
0
Polygon -7500403 true true 75 165 165 30 195 30 195 165 225 165 225 195 195 195 195 270 165 270 165 195 75 195 75 165 165 165 164 84 109 165

num-5
false
0
Polygon -7500403 true true 75 119 105 149 123 139 141 133 158 133 173 139 185 148 192 161 196 177 196 195 191 216 179 233 161 242 137 242 119 237 108 224 105 209 75 209 76 223 78 234 83 243 94 256 105 262 122 267 150 269 164 268 179 263 197 253 212 237 221 219 225 194 224 165 220 148 210 133 193 117 173 108 154 106 132 107 114 114 105 119
Polygon -7500403 true true 75 150 105 150 105 60 225 60 225 30 75 30 75 150

num-6
false
0
Polygon -7500403 true true 75 180 75 195 75 210 75 196 80 225 80 225 84 237 89 247 96 253 106 262 121 267 137 269 152 269 167 269 188 266 204 258 216 244 225 225 225 210 226 184 217 161 204 148 191 140 173 136 153 135 134 136 120 139 111 142 100 149 92 155 86 162 75 180 105 180 114 168 130 161 147 159 163 160 177 163 190 169 197 179 200 194 200 210 197 225 186 238 170 245 148 245 126 241 113 229 107 210 105 195 105 180
Polygon -2674135 true false 105 195
Polygon -2674135 true false 165 30 195 30
Polygon -7500403 true true 224 84 225 105 195 105 193 84 183 69 171 62 150 61 129 65 114 79 108 95 106 120 105 139 104 156 75 195 75 150 75 120 81 82 93 58 109 42 131 33 159 29 187 35 207 49 220 67

num-7
false
0
Polygon -7500403 true true 75 31 225 31 225 61 165 136 120 271 90 271 135 121 180 61 75 61

num-8
false
0
Polygon -7500403 true true 166 98 177 90 184 81 184 70 178 59 167 51 154 47 142 47 129 52 123 58 119 68 118 80 121 89 132 97 138 100 150 105 120 122 109 115 102 110 95 102 90 86 90 65 93 49 102 36 114 25 132 18 150 16 165 17 180 21 192 27 207 40 213 57 213 73 211 90 203 105 190 114 180 121 150 106
Polygon -7500403 true true 150 135 135 144 123 152 114 162 107 173 103 191 102 208 105 223 112 234 124 241 139 246 158 246 172 242 186 233 195 221 197 200 195 183 189 168 180 155 166 144 150 134 150 105 120 122 104 134 98 141 93 146 84 158 78 175 75 196 77 225 87 245 101 257 116 266 136 271 165 271 190 263 208 249 221 226 225 196 221 175 211 156 200 140 185 126 174 116 150 106

num-9
false
0
Polygon -7500403 true true 225 119 225 112 223 115 225 103 224 84 221 71 217 62 211 52 205 44 194 37 179 32 163 30 148 30 133 30 112 33 96 41 84 55 77 73 75 89 75 107 78 128 84 142 98 153 111 159 132 164 155 165 174 163 187 158 201 150 208 144 219 130 225 119 195 119 186 131 175 138 162 140 142 140 125 138 111 133 103 120 100 105 100 89 104 71 115 59 133 54 152 53 172 55 184 61 193 76 196 98 195 119
Polygon -2674135 true false 195 105
Polygon -2674135 true false 135 270 105 270
Polygon -7500403 true true 77 226 75 211 75 196 105 196 105 211 109 230 127 242 148 244 168 242 183 232 193 208 196 176 196 145 225 105 225 151 224 177 221 208 214 230 202 249 184 265 161 270 127 270 104 263 85 248

num-minus
false
0
Rectangle -7500403 true true 105 135 195 165

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person cutting
false
0
Circle -7500403 true true 65 5 80
Polygon -7500403 true true 60 90 75 195 45 285 60 300 90 300 105 225 120 300 150 300 165 285 135 195 150 90
Rectangle -7500403 true true 82 79 127 94
Polygon -7500403 true true 150 90 195 150 180 180 120 105
Polygon -7500403 true true 60 90 15 150 30 180 90 105
Polygon -6459832 true false 165 210 210 120 240 120 255 120 270 90 285 60 285 30 255 15 210 0 255 45 255 90 225 105 210 105 165 195

person resting
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Line -16777216 false 125 39 140 39
Line -16777216 false 155 39 170 39
Circle -16777216 true false 136 55 15

person walking
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 165 285 135 270 150 225 210 270 255 210 225 225 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 255 105 240 135 165 120
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Polygon -16777216 true false 120 105 150 105 150 90 180 120 150 150 150 135 120 135

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

player-action-cropping
false
0
Circle -13840069 false false 0 0 300
Polygon -14835848 true false 120 270 120 240 90 195 120 210 120 195 90 165 120 180 120 150 90 105 120 120 120 90 90 60 120 75 120 45 105 30 135 45 165 30 150 45 150 75 165 75 150 90 150 120 180 90 150 150 165 150 150 165 150 195 180 165 150 210 180 195 150 240 150 270
Circle -1184463 true false 90 90 30
Circle -1184463 true false 150 90 30
Circle -1184463 true false 150 135 30
Circle -1184463 true false 150 180 30
Circle -1184463 true false 90 180 30
Circle -1184463 true false 90 135 30
Circle -1184463 true false 90 45 30
Circle -1184463 true false 150 45 30

player-action-industry
false
0
Rectangle -13345367 true false 45 75 195 195
Polygon -13345367 true false 281 193 281 150 244 134 229 104 193 104 192 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 223 112 237 141 204 141 203 112
Circle -16777216 true false 219 174 42
Circle -16777216 true false 144 174 42
Circle -16777216 true false 54 174 42
Circle -7500403 false true 54 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 219 174 42
Circle -14835848 false false 0 0 300

player-action-livestock
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123
Circle -10899396 false false 0 0 300

player-action-residential
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120
Circle -10899396 false false 2 2 295

raindrops
false
0
Polygon -13345367 true false 114 51 97 82 98 101 115 116 138 108 145 84 145 48 144 20
Polygon -13345367 true false 120 156 103 187 104 206 121 221 144 213 151 189 151 153 150 125
Polygon -13345367 true false 190 96 173 127 174 146 191 161 214 153 221 129 221 93 220 65
Polygon -13345367 true false 216 204 199 235 200 254 217 269 240 261 247 237 247 201 246 173
Polygon -13345367 true false 47 179 30 210 31 229 48 244 71 236 78 212 78 176 77 148

selection-rectangle
false
0
Rectangle -1 true false 30 120 270 180

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

sheep 2
false
0
Polygon -7500403 true true 209 183 194 198 179 198 164 183 164 174 149 183 89 183 74 168 59 198 44 198 29 185 43 151 28 121 44 91 59 80 89 80 164 95 194 80 254 65 269 80 284 125 269 140 239 125 224 153 209 168
Rectangle -7500403 true true 180 195 195 225
Rectangle -7500403 true true 45 195 60 225
Rectangle -16777216 true false 180 225 195 240
Rectangle -16777216 true false 45 225 60 240
Polygon -7500403 true true 245 60 250 72 240 78 225 63 230 51
Polygon -7500403 true true 25 72 40 80 42 98 22 91
Line -16777216 false 270 137 251 122
Line -16777216 false 266 90 254 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square outline
false
4
Polygon -1184463 true true 15 15 285 15 285 285 15 285 15 30 30 30 30 270 270 270 270 30 15 30

square-full
false
0
Rectangle -7500403 true true 15 15 285 285

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
VIEW
7
10
1087
730
0
0
0
1
1
1
1
1
0
1
1
1
-5
6
0
6

@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
