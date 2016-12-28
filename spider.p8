pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
-- sound effects
-- music
-- levels
-- final ending screen
-- respawn mechanics


-- global vars
local scene
local next_scene
local transition_frames_left=0
local scene_frame
local level_num
local score
local bugs_eaten
local timer
local frames_until_spawn_bug
local spawns_until_pause
local spider
local entities
local new_entities
local web_points
local web_strands
local tiles
local level_spawn_points


-- constants
local tile_symbols="abcdefghijklmnopqrstuvwxyz0123456789"
local tile_flip_matrix={8,4,2,1,128,64,32,16}
local scenes={}
local friends={
	["tutorial_spider"]={
		["dialog"]={
			[1]={{"can i ask you a question?"},{"sure"},{"i'd rather not",3}},
			[2]={{"do you ever think about how,/in the end, we're all just  /spiders? it keeps me up at  /night..."},{"all the time"},{"umm... no?"},{"eat him"}},
			[3]={{"oh..."}},
			[4]={{"nevermind then",-1}}
		}
	}
}
local friend_states={
	["tutorial_spider"]={
		["dialog_index"]=1
	}
}
local levels={
	-- spawn_x,spawn_y,tileset,tiles,is_bottomless
	{21,45,"cave","rssqvsqarqvssupaaqqaql  kprssvn  kl kh. ih kqql  mn.if..gf.ijkl  kl.gh..ef.ghmn  in.gf..cd.gfkl  ml.ef..  .efml  kn.ef.+...cdkj  il.ef.+++.  ih  gj.cd.+*++..gf  gh.  .+**++.ef  gh....+***+.cd  cd.++++++++.        .....                      ",true},
	{30,50,"construction","  uw   c   c   cqmoqs  c   c   c  uw ..ce..c   c .uw.+.kmoqs   c .uw.+.c   c   c .uw.++c...c.  c .uw.+*c+++c.  c .uw.+*c***c+. c .yw.+*c**+c++.c  uw.++c++.c...c  uw.+.c.+.kmoqs .uw...i...     qqmos..g.++..     uw  . .       aauwbbaabbaa aab",true},
	{63,17,"carrot","m77n        vrqn 45  ... vtr 66n 45  qsu   vr67n 45qsu  ... o65n opp  ..... m45 i20l..++++.. 45 e000j.+**+...45 e003f.+**+...45 g000f.+**+...op e020f.+**+. k20je000f.+**+.i000fe003h.++++.e200hg200j......g003jcyyydaaaaaacyyydwwwwwwwwwwwwwwww"},
	{28,116,"twig","                                                                                                   q               o               t               t             n s     i       dbs   egc         t egc           tack            t            ",true}
}
local tilesets={
	-- base_sprite,{solid_bits}
	["twig"]={145,{255,23, 23,0, 0,248, 232,55, 0,238, 103,0, 0,116, 238,238, 96,238}},
	["carrot"]={128,{240,255, 254,255, 204,204, 204,136, 200,204, 236,255, 204,204, 255,239, 232,254, 255,63, 127,1}},
	["construction"]={155,{0,0, 0,0, 0,255}},
	["cave"]={168,{255,9, 136,136, 136,136, 204,136, 238,204, 255,239, 254,255}}
}
local bug_species={
	-- species_name,base_sprite,colors,points,wiggles
	{"fly",64,{12,13,5,1},1,true},
	{"beetle",80,{8,13,2,1},2},
	{"firefly",96,{9,4,2,1},3},
	{"hornet",112,{10,9,5,1},5,true},
	{"dragonfly",71,{11,3,5,1},5,true}
}
local entity_classes={
	["spider"]={
		["render_layer"]=6,
		["gravity"]=0.05,
		["mass"]=4,
		["webbing"]=70,
		["max_webbing"]=70,
		["facing_x"]=0,
		["facing_y"]=1,
		-- ["is_on_tile"]=false,
		-- ["is_on_web"]=false,
		-- ["is_in_freefall"]=false,
		-- ["is_spinning_web"]=false,
		-- ["is_placing_web"]=false,
		-- ["spun_strand"]=nil,
		["frames_until_spin_web"]=0,
		["web_uncollision_frames"]=0,
		["hitstun_frames"]=0,
		["update"]=function(entity)
			-- decrement counters
			decrement_counter_prop(entity,"web_uncollision_frames")
			decrement_counter_prop(entity,"hitstun_frames")
			-- figure out if the spider is supported by anything
			local web_x,web_y,web_square_dist=calc_closest_spot_on_web(entity.x,entity.y,false)
			entity.is_on_web=web_x!=nil and web_square_dist<=9 and entity.web_uncollision_frames<=0 and entity.hitstun_frames<=0
			entity.is_on_tile=is_solid_tile_at(entity.x,entity.y) and entity.hitstun_frames<=0
			entity.is_in_freefall=not entity.is_on_tile and not entity.is_on_web
			-- when on web, the spider is pulled towards the strands
			if entity.is_on_web and not entity.is_on_tile then
				entity.x+=(web_x-entity.x)/5
				entity.y+=(web_y-entity.y)/5
			end
			-- the spider falls if unsupported
			if entity.is_in_freefall then
				entity.vy+=entity.gravity
			-- move the spider
			else
				entity.vx=(btn(1) and 1 or 0)-(btn(0) and 1 or 0)
				entity.vy=(btn(3) and 1 or 0)-(btn(2) and 1 or 0)
				-- make sure the spider doesn't move faster when moving diagonally
				if entity.vx!=0 and entity.vy!=0 then
					entity.vx*=0.7
					entity.vy*=0.7
				end
			end
			-- the spider stays under the speed limit
			entity.vx=mid(-2,entity.vx,2)
			entity.vy=mid(-2,entity.vy,2)
			-- apply the spider's velocity
			entity.x+=entity.vx
			entity.y+=entity.vy
			-- keep track of which direction the spider is facing
			local speed=sqrt(entity.vx*entity.vx+entity.vy*entity.vy)
			if entity.vx!=0 or entity.vy!=0 then
				entity.facing_x=entity.vx/speed
				entity.facing_y=entity.vy/speed
			end
			decrement_counter_prop(entity,"frames_until_spin_web")
			-- the spider stops spinning web if it gets cut off at the base
			if (entity.is_spinning_web or entity.is_placing_web) and not entity.spun_strand.is_alive then
				entity.is_spinning_web,entity.is_placing_web,entity.spun_strand=false -- ,false,nil
				entity.finish_spinning_web(entity)
			end
			-- the spider places a spun web when z is pressed
			if entity.is_placing_web and btnp(4) then
				local web_point=entity.spin_web_point(entity,true,false,true)
				entity.spun_strand.from=web_point
				entity.is_placing_web,entity.spun_strand=false -- ,nil
				if web_point.is_in_freefall and not web_point.has_been_anchored and speed>0.8 then
					entity.web_uncollision_frames=4
				end
				entity.finish_spinning_web(entity)
			-- the spider starts spinning web when z is pressed
			elseif not entity.is_spinning_web and btnp(4) and entity.webbing>0 then
				entity.is_spinning_web,entity.frames_until_spin_web=true,0
				entity.spun_strand=create_entity("web_strand",{["from"]=entity,["to"]=entity.spin_web_point(entity,true,true,false)})
			-- the spider stops spinning web when z is no longer held
			elseif entity.is_spinning_web and not btn(4) then
				entity.is_placing_web,entity.is_spinning_web=true -- ,false
			end
			-- the spider continuously creates web while z is held
			if entity.is_spinning_web and entity.frames_until_spin_web<=0 and entity.webbing>0 then
				local web_point=entity.spin_web_point(entity,false,true,false)
				entity.spun_strand.from=web_point
				entity.frames_until_spin_web,entity.spun_strand=5,create_entity("web_strand",{["from"]=entity,["to"]=web_point})
				decrement_counter_prop(entity,"webbing")
			end
			-- the spider stays in bounds
			entity.x=mid(3,entity.x,124)
			-- the spider can fall off the bottom of bottomless levels
			if levels[level_num][5] then
				entity.y=max(2,entity.y)
				if entity.y>=130 then
					entity.die(entity)
				end
			else
				entity.y=mid(2,entity.y,116)
			end
		end,
		["draw"]=function(entity)
			local sprite,dx,dy,flipped_x,flipped_y=29,3.5,3.5
			if entity.facing_x<-0.4 then
				flipped_x,dx=true,2.5
			elseif entity.facing_x<0.4 then
				sprite=13
			end
			if entity.facing_y<-0.4 then
				flipped_y,dy=true,2.5
			elseif entity.facing_y<0.4 then
				sprite=45
			end
			-- flip through the walk cycle
			if not entity.is_in_freefall and (entity.vx!=0 or entity.vy!=0) then
				sprite+=1+flr(scene_frame%10/5)
			end
			if spider.hitstun_frames%4<2 then
				spr(sprite,entity.x-dx,entity.y-dy,1,1,flipped_x,flipped_y)
			end
		end,
		["on_death"]=function()
			-- create new spider
		end,
		["spin_web_point"]=function(entity,can_be_fixed,is_being_spun,prefer_tile)
			local is_fixed=can_be_fixed and is_solid_tile_at(entity.x,entity.y)
			-- search for an existing web point
			if can_be_fixed and (not is_fixed or not prefer_tile) then
				local web_point,square_dist=calc_closest_web_point(entity.x,entity.y,true,true)
				if web_point and square_dist<81 then
					return web_point
				end
			end
			-- otherwise just create a new one
			return create_entity("web_point",{
				["x"]=entity.x,
				["y"]=entity.y,
				["vx"]=entity.vx-entity.facing_x,
				["vy"]=entity.vy-entity.facing_y,
				["has_been_anchored"]=is_fixed,
				["is_being_spun"]=is_being_spun,
				["is_in_freefall"]=not is_fixed
			})
		end,
		["finish_spinning_web"]=function(entity)
			foreach(web_points,function(web_point)
				web_point.is_being_spun=false
			end)
		end
	},
	["web_point"]={
		["mass"]=1,
		-- ["has_strands_attached"]=false,
		-- ["caught_bug"]=nil,
		["add_to_game"]=function(entity)
			add(web_points,entity)
		end,
		["update"]=function(entity)
			if entity.is_in_freefall then
				entity.vx=0.9*mid(-3,entity.vx,3)
				entity.vy=0.9*mid(-3,entity.vy+0.02,3)
				entity.x+=entity.vx
				entity.y+=entity.vy
			end
			if entity.x<-20 or entity.x>147 or entity.y<-20 or entity.y>180 then
				entity.die(entity)
			end
			-- we use a silly solution to count strand connections
			-- a point without any strands shouldn't exist
			if entity.frames_alive>1 and not entity.has_strands_attached then
				entity.die(entity)
			end
			entity.has_strands_attached=false
		end
	},
	["web_strand"]={
		["render_layer"]=3,
		["stretched_length"]=5,
		["percent_elasticity_remaining"]=1,
		-- ["spring_force"]=0.25,
		-- ["elasticity"]=1.65,
		-- ["base_length"]=5,
		-- ["break_length"]=25,
		["add_to_game"]=function(entity)
			add(web_strands,entity)
		end,
		["update"]=function(entity)
			local from,to=entity.from,entity.to
			-- count points attached to the strand
			from.has_strands_attached=true
			to.has_strands_attached=true
			-- strands transfer anchored status
			if from.class_name=="web_point" and to.class_name=="web_point" and not from.is_being_spun and not to.is_being_spun and (from.has_been_anchored or to.has_been_anchored) then
				from.has_been_anchored=true
				to.has_been_anchored=true
			end
			-- find the current length of the strand
			local dx,dy=to.x-from.x,to.y-from.y
			local len=sqrt(dx*dx+dy*dy)
			-- if the strand stretches too far, it loses elasticity
			local percent_elasticity=mid(0,(25-len)/11.75,1)
			if percent_elasticity<entity.percent_elasticity_remaining then
				entity.percent_elasticity_remaining,entity.stretched_length=percent_elasticity,len/(1+1.65*percent_elasticity)
			end
			-- bring the two points closer to each other
			if len>entity.stretched_length and entity.percent_elasticity_remaining>0 then
				local f=(len-entity.stretched_length)/4
				local from_mult,to_mult=f*to.mass/from.mass/len,f*from.mass/to.mass/len
				if from.is_in_freefall then
					from.vx+=mid(-2,from_mult*dx,2)
					from.vy+=mid(-2,from_mult*dy,2)
				end
				if to.is_in_freefall then
					to.vx-=mid(-2,to_mult*dx,2)
					to.vy-=mid(-2,to_mult*dy,2)
				end
			end
			-- die if the strand gets too long or if the points die
			if len>=25 or not from.is_alive or not to.is_alive then
				entity.die(entity)
			end
		end,
		["draw"]=function(entity)
			line(entity.from.x,entity.from.y,entity.to.x,entity.to.y,({8,8,9,15,7})[ceil(1+4*entity.percent_elasticity_remaining)])
		end
	},
	["bug_spawn_flash"]={
		["render_layer"]=1,
		["frames_to_death"]=15,
		["draw"]=function(entity)
			if entity.frames_to_death<=15 then
				colorwash(bug_species[entity.species][3][1])
				spr(92-ceil(entity.frames_to_death/3),entity.x-3,entity.y-4)
				pal()
			end
		end,
		["on_death"]=function(entity)
			create_entity("bug",extract_props(entity,{"species","x","y"}))
		end
	},
	["bug"]={
		["render_layer"]=2,
		-- ["is_catchable"]=false,
		-- ["caught_web_point"]=nil,
		["frames_until_escape"]=0,
		["vy"]=0.35,
		["init"]=function(entity)
			local k,v
			for k,v in pairs({"species_name","base_sprite","colors","points","wiggles"}) do
				entity[v]=bug_species[entity.species][k]
			end
			create_entity("ripple",{["target"]=entity})
		end,
		["update"]=function(entity)
			-- bugs move downwards while spawning
			if entity.frames_alive<45 then
				entity.vy*=0.95
			-- bugs become catchable after spawning
			elseif entity.frames_alive==45 then
				entity.render_layer=4
				entity.is_catchable=true
				entity.vy=0
			-- bugs escape after a pause
			elseif entity.frames_alive>80 and entity.is_catchable then
				entity.escape(entity)
			end
			-- bugs can be caught in webs
			if entity.is_catchable then
				local web_point
				local square_dist
				web_point,square_dist=calc_closest_web_point(entity.x,entity.y,true,false)
				if web_point and square_dist<64 then
					entity.is_catchable=false
					entity.caught_web_point=web_point
					web_point.caught_bug=entity
					entity.frames_until_escape=rnd_int(120,150)
					if entity.species_name=="firefly" then
						entity.frames_until_escape=140
					elseif entity.species_name=="dragonfly" then
						entity.frames_until_escape*=2
					end
				end
			end
			-- bugs escape webs in time or if they break
			if entity.frames_until_escape>0 and entity.caught_web_point then
				decrement_counter_prop(entity,"frames_until_escape")
				if entity.frames_until_escape<=0 then
					-- fireflies explode, actually
					if entity.species_name=="firefly" then
						create_entity("firefly_explosion",extract_props(entity,{"x","y"}))
						local x
						local y
						foreach(web_points,function(web_point)
							local dist=sqrt(calc_square_dist(entity.x,entity.y,web_point.x,web_point.y))
							if dist<10 then
								web_point.die(web_point)
							elseif dist<30 then
								x,y=create_vector(web_point.x-entity.x,web_point.y-entity.y,(30-dist)/8)
								web_point.vx+=x
								web_point.vy+=y
							end
						end)
						if spider and spider.is_alive then
							if calc_square_dist(entity.x,entity.y,spider.x,spider.y)<625 then
								x,y=create_vector(spider.x-entity.x,spider.y-entity.y,1.5)
								spider.hitstun_frames=25
								spider.vx=x
								spider.vy=y
							end
						end
						entity.die(entity)
					else
						entity.escape(entity)
					end
				-- dragonflies shoot projectiles
				elseif entity.frames_until_escape%80==0 and entity.species_name=="dragonfly" then
					create_entity("dragonfly_fireball_spawn",{
						["bug"]=entity
					})
				end
			end
			if entity.caught_web_point and not entity.caught_web_point.is_alive then
				entity.escape(entity)
			end
			-- move the bug
			if entity.caught_web_point then
				entity.x=entity.caught_web_point.x
				entity.y=entity.caught_web_point.y
				-- wiggle the web point too
				if entity.wiggles and entity.frames_until_escape%4==0 then
					entity.caught_web_point.vx+=rnd(1)-0.5
					entity.caught_web_point.vy+=rnd(1)-0.5
				end
			else
				entity.x+=entity.vx
				entity.y+=entity.vy
			end
			-- bugs can be eaten by the spider
			if spider and spider.is_alive and 49>calc_square_dist(spider.x,spider.y,entity.x,entity.y) then
				if entity.species_name=="hornet" and entity.is_catchable then
					if spider.hitstun_frames<=0 then
						spider.hitstun_frames=25
						spider.vy=-1.5
						spider.vx*=0.5
					end
				elseif entity.is_catchable or entity.caught_web_point then
					local props=extract_props(entity,{"colors","x","y"})
					props.text="+"..entity.points.."0"
					create_entity("floating_points",props)
					score+=entity.points
					bugs_eaten+=1
					spider.webbing=min(spider.webbing+2,spider.max_webbing)
					entity.die(entity)
				end
			end
		end,
		["draw"]=function(entity)
			-- draw tri rings
			if entity.species_name=="hornet" and entity.is_catchable and not entity.caught_web_point then
				local i
				local f=entity.frames_alive/50
				for i=1,5 do
					local c=cos(f+0.33*i)
					local s=sin(f+0.33*i)
					local c2=cos(f+0.33*(i+1))
					local s2=sin(f+0.33*(i+1))
					line(entity.x+7*c,entity.y+7*s,entity.x+7*c2,entity.y+7*s2,8)
				end
			end
			-- draw the actual bug
			local sprite=entity.base_sprite
			if entity.caught_web_point then
				sprite+=4+flr(entity.frames_alive/5)%3
				if entity.species_name=="firefly" and entity.frames_until_escape<105 and entity.frames_until_escape%35>25 then
					colorwash(8)
				end
			else
				if entity.frames_alive%6<3 then
					sprite+=1
				end
				if entity.is_catchable then
					sprite+=2
				end
				if entity.frames_to_death>0 then
					sprite+=2
					colorwash(entity.colors[4-flr(entity.frames_to_death/4)])
				end
			end
			spr(sprite,entity.x-3,entity.y-4)
			pal()
			-- draw countdown
			if entity.species_name=="firefly" and entity.caught_web_point and entity.frames_until_escape<=105 then
				print(ceil(entity.frames_until_escape/35),entity.x,entity.y-10,8)
			end
		end,
		["escape"]=function(entity)
			if entity.caught_web_point then
				-- beetles chew through web
				if entity.species_name=="beetle" then
					entity.caught_web_point.die(entity.caught_web_point)
				end
				entity.caught_web_point.caught_bug=nil
				entity.caught_web_point=nil
			end
			entity.render_layer=7
			entity.is_catchable=false
			entity.frames_to_death=12
			entity.vy=-1.5
		end,
		["on_death"]=function(entity)
			if entity.caught_web_point then
				entity.caught_web_point.caught_bug=nil
			end
		end
	},
	["dragonfly_fireball_spawn"]={
		["render_layer"]=3,
		["frames_to_death"]=30,
		["draw"]=function(entity)
			local bug=entity.bug
			local f=entity.frames_alive
			local s=sin(f/100)
			local c=cos(f/100)
			local d=10-f/3
			local r=f/20
			color(8)
			circfill(bug.x+d*s,bug.y+d*c,r)
			circfill(bug.x-d*s,bug.y-d*c,r)
			circfill(bug.x-d*c,bug.y+d*s,r)
			circfill(bug.x+d*c,bug.y-d*s,r)
		end,
		["on_death"]=function(entity)
			if entity.bug.is_alive and entity.bug.caught_web_point and spider and spider.is_alive then
				local dx=spider.x-entity.bug.x
				local dy=spider.y-entity.bug.y
				local dist=max(1,sqrt(dx*dx+dy*dy))
				create_entity("dragonfly_fireball",{
					["x"]=entity.bug.x,
					["y"]=entity.bug.y,
					["vx"]=dx/dist,
					["vy"]=dy/dist
				})
			end
		end
	},
	["dragonfly_fireball"]={
		["frames_to_death"]=150,
		["render_layer"]=5,
		["update"]=function(entity)
			entity.x+=entity.vx
			entity.y+=entity.vy
			if spider and spider.is_alive and spider.hitstun_frames<=0 and 9>calc_square_dist(entity.x,entity.y,spider.x,spider.y) then
				spider.hitstun_frames=25
				spider.vx*=0.5
				spider.vy=-1.5
				entity.die(entity)
			end
		end,
		["draw"]=function(entity)
			circfill(entity.x,entity.y,1,8)
		end
	},
	["firefly_explosion"]={
		["frames_to_death"]=18,
		["render_layer"]=2,
		["draw"]=function(entity)
			local f=flr(entity.frames_alive)
			local x=entity.x+rnd(2)-1
			local y=entity.y+rnd(2)-1
			local r=9+1.8*f-f*f/20
			if f>=12 then
				color(1)
			else
				color(7-flr(f/4))
			end
			if f<16 then
				circfill(x,y,r)
			else
				circ(x,y,r)
			end
		end
	},
	["floating_points"]={
		["render_layer"]=8,
		["frames_to_death"]=20,
		["update"]=function(entity)
			entity.y-=0.5
		end,
		["draw"]=function(entity)
			print(entity.text,entity.x-2*#entity.text,entity.y-2,entity.colors[max(1,flr(entity.frames_alive/2-5))])
		end
	},
	["ripple"]={
		["render_layer"]=1,
		["frames_to_death"]=48,
		["draw"]=function(entity)
			circ(entity.target.x,entity.target.y,15-entity.frames_alive/4,1)
		end
	},
	["character_portrait"]={
		["draw"]=function(entity)
			color(7)
			local x,y=entity.x,entity.y
			if entity.is_highlighted then
				spr(44,x-10,y-10)
				spr(44,x+4,y-10,1,1,true)
				spr(44,x-10,y+4,1,1,false,true)
				spr(44,x+4,y+4,1,1,true,true)
				line(x-4,y-10,x+5,y-10)
				line(x-4,y+11,x+5,y+11)
				line(x-10,y-4,x-10,y+5)
				line(x+11,y-4,x+11,y+5)
			else
				colorwash(13)
				rect(x-9,y-9,x+10,y+10)
			end
			sspr(48,0,16,16,x-7,y-7)
			pal()
		end
	},
	["dialog_screen"]={
		["buttons"]={},
		["button_index"]=0,
		["init"]=function(entity)
			entity.speaker=create_entity("character_portrait",{
				["is_highlighted"]=true,
				["x"]=63,
				["y"]=18
			})
			entity.load_dialog(entity,entity.friend_state.dialog_index)
		end,
		["update"]=function(entity)
			local speech_box=entity.speech_box
			if btnp(4) then
				-- show the text and responses when z is pressed
				if speech_box.frames_fully_shown<8 then
					speech_box.fully_show(speech_box)
				-- if they are already shown, move on to the next dialog when z is pressed
				elseif speech_box.frames_fully_shown>12 then
					local next_dialog_index=entity.dialog[entity.button_index+1][2]
					if not next_dialog_index then
						next_dialog_index=entity.friend_state.dialog_index+1
					end
					if next_dialog_index==-1 then
						-- quit dialog?
					else
						entity.load_dialog(entity,next_dialog_index)
					end
				end
			end
			if speech_box.frames_fully_shown>8 then
				local buttons,dy,i=entity.buttons,({15,7,0,-15})[#entity.dialog-1]
				-- create buttons once the text is fully shown
				if #buttons<#entity.dialog-1 then
					for i=2,#entity.dialog do
						add(buttons,create_entity("dialog_button",{
							["text"]=entity.dialog[i][1],
							["y"]=48+15*i+dy
						}))
					end
					entity.button_index,buttons[1].is_highlighted=1,true
				end
				-- scroll up and down through the buttons
				if #buttons>0 and (btnp(2) or btnp(3)) then
					buttons[entity.button_index].is_highlighted=false
					if btnp(3) then
						entity.button_index=min(entity.button_index+1,#buttons)
					elseif btnp(2) then
						entity.button_index=max(entity.button_index-1,1)
					end
					buttons[entity.button_index].is_highlighted=true
				end
			end
		end,
		["load_dialog"]=function(entity,dialog_index)
			-- destroy existing entities
			if entity.speech_box then
				entity.speech_box.die(entity.speech_box)
			end
			foreach(entity.buttons,function(dialog_button)
				dialog_button.die(dialog_button)
			end)
			entity.buttons={}
			-- load dialog state
			entity.button_index,entity.friend_state.dialog_index,entity.dialog=0,dialog_index,entity.friend.dialog[dialog_index]
			-- create a speech box
			entity.speech_box=create_entity("speech_box",{
				["text"]=entity.dialog[1][1],
				["characters_per_line"]=28,
				["show_blinky_arrow"]=#entity.dialog<=1,
				["x"]=8,
				["y"]=35
			})
		end
	},
	["dialog_button"]={
		-- ["is_highlighted"]=false,
		["draw"]=function(entity)
			local y,d,d2=entity.y,0,0
			if entity.is_highlighted then
				line(11,y+11,116,y+11,5)
				color(7)
				spr(60,57,y-4)
				spr(60,62,y-4,1,1,true)
				spr(61,57,y+7)
				spr(61,62,y+7,1,1,true)
				d2=7
			else
				colorwash(13)
				d=2
			end
			line(15,y,63-d2,y)
			line(63+d2,y,112,y)
			line(15,y+10,63-d2,y+10)
			line(63+d2,y+10,112,y+10)
			spr(28,7+d,y-1)
			spr(28,7+d,y+4,1,1,false,true)
			spr(28,113-d,y-1,1,1,true)
			spr(28,113-d,y+4,1,1,true,true)
			print(entity.text,64-2*#entity.text,y+3)
			pal()
		end
	},
	["speech_box"]={
		["characters_shown"]=0,
		["frames_fully_shown"]=0,
		["update"]=function(entity)
			entity.characters_shown=min(entity.characters_shown+1,#entity.text)
			if entity.characters_shown>=#entity.text then
				entity.frames_fully_shown=increment_looping_counter(entity.frames_fully_shown)
			end
		end,
		["draw"]=function(entity)
			local c,r=entity.characters_per_line
			for r=0,3 do
				local text=sub(entity.text,c*r+r+1,min(entity.characters_shown,c*r+r+c))
				print(text,entity.x,entity.y+9*r,7)
				if entity.show_blinky_arrow and entity.frames_fully_shown%30>10 and flr(#entity.text/c)==r then
					spr(59,entity.x+4*#text,entity.y+9*r)
				end
			end
		end,
		["fully_show"]=function(entity)
			entity.characters_shown=#entity.text
			entity.frames_fully_shown=10
		end
	},
	["character_grid"]={
		-- ["selected_character"]=nil,
		["row"]=2,
		["col"]=2,
		["characters"]={},
		["init"]=function(entity)
			local r,c
			for r=1,3 do
				entity.characters[r]={}
				for c=1,3 do
					entity.characters[r][c]=create_entity("character_portrait",{
						["is_highlighted"]=false,
						["x"]=entity.x+30*c-60,
						["y"]=entity.y+30*r-60
					})
				end
			end
		end,
		["update"]=function(entity)
			-- button presses move you about the grid
			local button_pressed=false
			if btnp(0) then
				entity.col,button_pressed=wrap_number(entity.col-1,1,3),true
			end
			if btnp(1) then
				entity.col,button_pressed=wrap_number(entity.col+1,1,3),true
			end
			if btnp(2) then
				entity.row,button_pressed=wrap_number(entity.row-1,1,3),true
			end
			if btnp(3) then
				entity.row,button_pressed=wrap_number(entity.row+1,1,3),true
			end
			if button_pressed then
				if entity.selected_character then
					entity.selected_character.is_highlighted=false
				end
				entity.selected_character=entity.characters[entity.row][entity.col]
				entity.selected_character.is_highlighted=true
			end
			-- pressing z selects a character and begins a conversations
			if entity.selected_character and btnp(4) then
				init_scene("conversation")
			end
		end
	}
}


-- main functions
function _init()
	init_scene("title")
end

function _update()
	if transition_frames_left>0 then
		transition_frames_left=decrement_counter(transition_frames_left)
		if transition_frames_left==30 then
			init_scene(next_scene)
			next_scene=nil
		end
	end
	scene_frame=increment_looping_counter(scene_frame)
	scenes[scene][2]()
end

function _draw()
	camera()
	rectfill(0,0,127,127,0)
	-- draw guidelines
	-- color(1)
	-- line(0,0,0,127)
	-- line(31,0,31,127)
	-- line(62,0,62,127)
	-- line(65,0,65,127)
	-- line(96,0,96,127)
	-- line(127,0,127,127)
	-- line(0,0,127,0)
	-- line(0,62,127,62)
	-- line(0,31,127,31)
	-- line(0,96,127,96)
	-- line(0,65,127,65)
	-- line(0,127,127,127)
	-- draw the scene
	scenes[scene][3]()
	-- draw the scene transition
	camera()
	if transition_frames_left>0 then
		local t,x,y=transition_frames_left
		if t<30 then
			t+=30
		end
		for y=0,128,6 do
			for x=0,128,6 do
				local size=mid(0,50-t+y/10-x/40,4)
				if transition_frames_left<30 then
					size=4-size
				end
				if size>0 then
					circfill(x,y,size,0)
				end
			end
		end
	end
	-- draw debug stats
	-- camera()
	-- color(15)
	-- print("entities: "..#entities,2,110)
	-- print("memory:   "..flr(stat(0)*(100/1024)).."%",2,116)
	-- print("cpu:      "..flr(100*stat(1)).."%",2,122)
end


-- title functions
function init_title()
	level_num=1
end

function update_title()
	if btnp(4) and scene_frame>15 then
		transition_to_scene("game")
	end
end

function draw_title()
	sspr(0,0,48,32,40,32)
	line(73,64,73,80,7)
	spr(13,69,81)
	if scene_frame%30<20 then
		print("press z to start",32,106,7)
	end
end


-- game functions
function init_game()
	local level=levels[level_num]
	init_simulation()
	score,bugs_eaten,timer,frames_until_spawn_bug,spawns_until_pause=0,0,120,0,3
	load_tiles(level[4],level[3])
	spider=create_entity("spider",{["x"]=level[1],["y"]=level[2]})
end

function update_game()
	-- count down the timer
	if scene_frame%30==0 then
		if timer<=0 then
			transition_to_scene("scoring")
		end
		timer=decrement_counter(timer)
	end

	-- spawn bugs from 1:30 to 0:04
	if timer==mid(4,timer,90) then
		local phase=min(flr(4-timer/30),3)
		-- spawn a new bug every so often
		frames_until_spawn_bug=decrement_counter(frames_until_spawn_bug)
		if frames_until_spawn_bug<=0 then
			local max_bug_type,dir_x,dir_y,num_bugs,r,bug_type,i=flr(0.5+(level_num+phase)/1.5),rnd_int(-1,1),rnd_int(-1,1),rnd_int(1,3),rnd(1),1
			if dir_x==0 and dir_y==0 then
				dir_x=1
			end
			local spawn_point=level_spawn_points[num_bugs][rnd_int(1,#level_spawn_points[num_bugs])]
			for i=5,2,-1 do
				if r<i/10 and max_bug_type>=i then
					bug_type=i
				end
			end
			if bug_type>=max_bug_type then
				num_bugs=1 -- fine that this is after num_bugs is first used
			end
			for i=1,num_bugs do
				create_entity("bug_spawn_flash",{
					["frames_to_death"]=15*i,
					["species"]=bug_type,
					["x"]=8*(spawn_point[1]+i*dir_x-dir_x)-5,
					["y"]=8*(spawn_point[2]+i*dir_y-dir_y)-10
				})
			end
			-- phase 1: 1.0s to 2.5s between spawns
			-- phase 2: 0.5s to 2.0s between spawns
			-- phase 3: 0.5s to 1.0s between spawns
			frames_until_spawn_bug=15*flr(num_bugs+max(1,3-phase)+rnd(min(8-2*phase,4)))
			-- after every couple of spawns, there is a pause
			spawns_until_pause=decrement_counter(spawns_until_pause)
			if spawns_until_pause<=0 then
				spawns_until_pause=rnd_int(3,3+2*phase)
				frames_until_spawn_bug+=120
			end
		end
	end

	update_simulation()
end

function draw_game()
	camera(0,-8)
	draw_simulation()
	-- draw ui
	camera()
	-- rectfill(0,0,127,7,0)
	-- draw webbing meter
	color(spider.is_spinning_web and 7 or 5)
	rectfill(35,2,35+50*spider.webbing/spider.max_webbing,5)
	rect(35,1,85,6)
	spr(62,87,0)
	-- draw timer
	if timer<=5 and scene_frame%30<=20 then
		color(8)
	else
		color(7)
	end
	print(flr(timer/60)..":"..(timer%60<10 and "0" or "")..timer%60,112,2)
	-- draw score
	print(score<=0 and "0" or score.."0",1,2,7)
end


-- character select functions
function init_character_select()
	init_simulation()
	create_entity("character_grid",{["x"]=63,["y"]=70})
end

function update_character_select()
	update_simulation()
end

function draw_character_select()
	draw_corners()
	print("pick someone to talk to",18,15,7)
	draw_simulation()
end


-- conversation functions
function init_conversation()
	init_simulation()
	create_entity("dialog_screen",{
		["friend"]=friends.tutorial_spider,
		["friend_state"]=friend_states.tutorial_spider
	})
end

function update_conversation()
	update_simulation()
end

function draw_conversation()
	draw_corners()
	draw_simulation()
end


-- scoring functions
function update_scoring()
	local final_frame=44+bugs_eaten+score
	if scene_frame>15 and btnp(4) then
		if scene_frame<final_frame then
			scene_frame=final_frame
		else
			transition_to_scene("title")
		end
	end
end

function draw_scoring()
	draw_corners()
	color(7)
	print("level complete!",35,24)
	line(35,30,92,30)
	local final_frame,f=44+bugs_eaten+score,scene_frame-40
	-- draw number of bugs eaten
	print("bugs eaten",15,50)
	local b=mid(0,f,bugs_eaten)
	if b>0 or b>=bugs_eaten and scene_frame>40 then
		print(b,110-4*#(""..b),50)
	end
	-- draw score
	print("score",15,68)
	if b>=bugs_eaten and scene_frame>40 then
		local s=mid(0,f-bugs_eaten,score)
		local score_text=s==0 and "0" or s.."0"
		print(score_text,110-4*#score_text,68)
	end
	-- draw continue text
	if scene_frame>=final_frame then
		if (scene_frame-final_frame)%30<20 then
			print("press z to continue",26,93,13)
		end
	end
end


-- simulation functions
function init_simulation()
	entities,new_entities,web_points,web_strands={},{},{},{}
	reset_tiles()
end

function update_simulation()
	-- update entities
	foreach(entities,function(entity)
		-- call the entity's update function
		entity.update(entity)
		-- do some default update stuff
		entity.frames_alive=increment_looping_counter(entity.frames_alive)
		if entity.frames_to_death>0 then
			entity.frames_to_death-=1
			if entity.frames_to_death<=0 then
				entity.die(entity)
			end
		end
	end)
	-- add new entities to the game
	add_new_entities_to_game()
	-- remove dead entities from the game
	filter_entity_list(entities)
	filter_entity_list(web_strands)
	filter_entity_list(web_points)
	-- sort entities for rendering
	sort_list(entities,function(a,b)
		return a.render_layer>b.render_layer
	end)
end

function draw_simulation()
	-- render layers:
	--  1=bg effects
	--  2=background
	--  tiles
	--  3=web
	--  4=midground
	--  5=projectiles
	--  6=spider
	--  7=foreground
	--  8=ui effects
	local j,i=#entities+1
	-- draw background entities
	for i=1,#entities do
		if entities[i].render_layer>2 then
			j=i
			break
		end
		entities[i].draw(entities[i])
	end
	-- draw the level
	foreach(tiles,function(tile)
		if tile then
			spr(tile.sprite,8*tile.col-8,8*tile.row-8,1,1,tile.is_flipped)
			-- uncomment to see terrain "hitboxes"
			-- if scene_frame%16<8 then
			-- 	local x=8*tile.col-8
			-- 	local y=8*tile.row-8
			-- 	local x2
			-- 	for x2=0,3 do
			-- 		local y2
			-- 		for y2=0,3 do
			-- 			local bit=1+x2+4*y2
			-- 			local should_draw
			-- 			if bit>8 then
			-- 				should_draw=band(2^(bit-9),tile.solid_bits[2])>0
			-- 			else
			-- 				should_draw=band(2^(bit-1),tile.solid_bits[1])>0
			-- 			end
			-- 			if should_draw then
			-- 				rectfill(x+2*x2,y+2*y2,x+2*x2+1,y+2*y2+1,7)
			-- 			end
			-- 		end
			-- 	end
			-- end
		end
	end)
	-- draw foreground entities
	for i=j,#entities do
		entities[i].draw(entities[i])
	end
end


-- entity functions
function create_entity(class_name,args)
	-- create default entity
	local entity,k,v={
		["class_name"]=class_name,
		["render_layer"]=4,
		["x"]=0,
		["y"]=0,
		["vx"]=0,
		["vy"]=0,
		["is_alive"]=0,
		["frames_alive"]=0,
		["frames_to_death"]=0,
		["add_to_game"]=noop,
		["init"]=noop,
		["update"]=noop,
		["draw"]=noop,
		["on_death"]=noop,
		["die"]=function(entity)
			entity.on_death(entity)
			entity.is_alive=false
		end
	}
	-- add class properties/methods onto it
	for k,v in pairs(entity_classes[class_name]) do
		entity[k]=v
	end
	-- add properties onto it from the arguments
	for k,v in pairs(args) do
		entity[k]=v
	end
	-- initialize it
	entity.init(entity,args)
	-- return it
	add(new_entities,entity)
	return entity
end

function add_new_entities_to_game()
	foreach(new_entities,function(entity)
		entity.add_to_game(entity)
		add(entities,entity)
	end)
	new_entities={}
end


-- tile functions
function reset_tiles()
	tiles,level_spawn_points={},{{},{},{}}
	local i
	for i=1,240 do
		tiles[i]=false
	end
end

function load_tiles(map,tileset_name)
	-- loop through the 2d array of symbols
	local c,r
	for c=1,16 do
		for r=1,15 do
			local tile_coords,s,tile_index,i={c,r},r*16+c-16
			local symbol=sub(map,s,s)
			-- find the tile index of the symbol
			for i=1,#tile_symbols do
				if symbol==sub(tile_symbols,i,i) then
					tile_index=i
					break
				end
			end
			-- create the tile if the symbol exists
			if tile_index then
				tiles[c*15+r-15]=create_tile(tilesets[tileset_name],tile_index,c,r)
			-- otherwise we may need to log it as a spawn point
			elseif symbol=="." then
				add(level_spawn_points[1],tile_coords)
			elseif symbol=="+" then
				add(level_spawn_points[1],tile_coords)
				add(level_spawn_points[2],tile_coords)
			elseif symbol=="*" then
				add(level_spawn_points[1],tile_coords)
				add(level_spawn_points[2],tile_coords)
				add(level_spawn_points[3],tile_coords)
			end
		end
	end
end

function create_tile(tileset,tile_index,col,row)
	local is_flipped,half_tile_index,solid_bits=(tile_index%2==0),ceil(tile_index/2),{255,255}
	if #tileset[2]>=2*half_tile_index then
		solid_bits={tileset[2][2*half_tile_index-1],tileset[2][2*half_tile_index]}
	end
	if is_flipped then
		for i=1,2 do
			local new_bits,j=0
			for j=1,#tile_flip_matrix do
				if band(solid_bits[i],2^(j-1))>0 then
					new_bits+=tile_flip_matrix[j]
				end
			end
			solid_bits[i]=new_bits
		end
	end
	return {
		["sprite"]=tileset[1]+half_tile_index-1,
		["col"]=col,
		["row"]=row,
		["is_flipped"]=is_flipped,
		["solid_bits"]=solid_bits
	}
end

function get_tile_at(x,y)
	if y>=0 and y<=116 then
		return tiles[1+flr(x/8)*15+flr(y/8)]
	end
end

function is_solid_tile_at(x,y)
	-- turn the position into a bit 1 to 16
	local tile,bit=get_tile_at(x,y),1+flr(x/2)%4+4*(flr(y/2)%4)
	if tile then
		-- check that against the tile's solid_bits
		if bit>8 then
			return band(2^(bit-9),tile.solid_bits[2])>0
		else
			return band(2^(bit-1),tile.solid_bits[1])>0
		end
	end
	return false
end


-- math functions
function rnd_int(min_val,max_val)
	return flr(min_val+rnd(1+max_val-min_val))
end

function ceil(n)
	return -flr(-n)
end

function wrap_number(n,min,max)
	return n<min and max or (n>max and min or n)
end

function create_vector(x,y,magnitude)
	local length=sqrt(x*x+y*y)
	if length==0 then
		return 0,0
	else
		return x*magnitude/length,y*magnitude/length
	end
end

function calc_square_dist(x1,y1,x2,y2)
	local dx,dy=x2-x1,y2-y1
	return dx*dx+dy*dy
end

function calc_closest_point_on_line(x1,y1,x2,y2,cx,cy)
	local dx,dy,match_x,match_y=x2-x1,y2-y1
	-- if the line is nearly vertical, it's easy
	if 0.1>dx and dx>-0.1 then
		match_x=x1
		match_y=cy
	-- if the line is nearly horizontal, it's also easy
	elseif 0.1>dy and dy>-0.1 then
		match_x=cx
		match_y=y1
	--otherwise we have a bit of math to do...
	else
		-- find equation of the line y=mx+b
		-- find reverse equation from circle
		local m,m2=dy/dx,-dx/dy
		local b,b2=y1-m*x1,cy-m2*cx -- b=y-mx  /  b=y-mx
		-- figure out where their y-values are the same
		match_x=(b2-b)/(m-m2) -- mx+b=m2x+b2 --> x=(b2-b)/(m-m2)
		-- plug that into either formula to get the y-value at that x-value
		match_y=m*match_x+b -- y=mx+b
	end
	if mid(x1,match_x,x2)==match_x and mid(y1,match_y,y2)==match_y then
		return match_x,match_y
	else
		return nil,nil
	end
end


-- web functions
function calc_closest_web_point(x,y,allow_unanchored,allow_occupied)
	local closest_web_point,closest_square_dist
	foreach(web_points,function(web_point)
		if not web_point.is_being_spun and
			(allow_occupied or not web_point.caught_bug) and
			(allow_unanchored or web_point.has_been_anchored) then
			local square_dist=calc_square_dist(x,y,web_point.x,web_point.y)
			if not closest_square_dist or square_dist<closest_square_dist then
				closest_web_point,closest_square_dist=web_point,square_dist
			end
		end
	end)
	return closest_web_point,closest_square_dist
end

function calc_closest_spot_on_web(x,y,allow_unanchored)
	local closest_x,closest_y
	local closest_web_point,closest_square_dist=calc_closest_web_point(x,y,allow_unanchored,true)
	if closest_web_point then
		closest_x,closest_y=closest_web_point.x,closest_web_point.y
	end
	foreach(web_strands,function(web_strand)
		if not web_strand.from.is_being_spun and not web_strand.to.is_being_spun and
			(allow_unanchored or (web_strand.from.has_been_anchored and web_strand.to.has_been_anchored)) then
			local x2,y2=calc_closest_point_on_line(
				web_strand.from.x,web_strand.from.y,
				web_strand.to.x,web_strand.to.y,
				x,y)
			if x2!=nil and y2!=nil then
				local square_dist=calc_square_dist(x,y,x2,y2)
				if not closest_square_dist or square_dist<closest_square_dist then
					closest_x,closest_y,closest_square_dist=x2,y2,square_dist
				end
			end
		end
	end)
	return closest_x,closest_y,closest_square_dist
end


-- draw helper functions
function draw_corners()
	spr(12,1,1)
	spr(12,119,1,1,1,true)
	spr(12,1,119,1,1,false,true)
	spr(12,119,119,1,1,true,true)
end


-- helper functions
function noop() end

function init_scene(s)
	scene,scene_frame=s,0
	scenes[scene][1]()
end

function transition_to_scene(s)
	next_scene=s
	if transition_frames_left<=0 then
		transition_frames_left=60
	end
end

function increment_looping_counter(n)
	if n>32000 then
		n-=10000
	end
	return n+1
end

function decrement_counter_prop(obj,k)
	obj[k]=decrement_counter(obj[k])
end

function decrement_counter(n)
	return max(0,n-1)
end

function colorwash(c)
	local i
	for i=1,15 do
		pal(i,c)
	end
end

function sort_list(list,func)
	local i
	for i=1,#list do
		local j=i
		while j>1 and func(list[j-1],list[j]) do
			list[j],list[j-1]=list[j-1],list[j]
			j-=1
		end
	end
end

function filter_entity_list(list)
	local num_deleted,i=0
	for i=1,#list do
		if not list[i].is_alive then
			list[i]=nil
			num_deleted+=1
		else
			list[i-num_deleted],list[i]=list[i],nil
		end
	end
end

function extract_props(obj,props_names)
	local props,i={}
	foreach(props_names,function(p)
		props[p]=obj[p]
	end)
	return props
end


-- set up the scenes now that the functions are defined
scenes={
	["title"]={init_title,update_title,draw_title},
	["game"]={init_game,update_game,draw_game},
	["character_select"]={init_character_select,update_character_select,draw_character_select},
	["conversation"]={init_conversation,update_conversation,draw_conversation},
	["scoring"]={noop,update_scoring,draw_scoring}
}


__gfx__
00000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000011011111000070000000700000007000
00000077770000000000070700000000000000000000000000077777777000000800080008000800080008000800080010100010000777000007770000077700
000077700d7700000000070700000000000000000000000000700000000700000080800000808000008080000080800001111100070777070007770707077700
00077600000770000500070700000000000000000000000000000000000000000008000000080000000800000008000010100000007777700777777000777777
00777000000070005050770600000000000000000000000000077700007770000080800000808000008080000080800010100000000777000007770000077700
007650000000d700d00077d000000000000000000000000000777070077707000800080008000800080008000800080010100000007171700771717000717177
00670000000007000ddd770000007770007700777dd0000000777070077707000000000000000000000000000000000011000000070707070007070707070700
0077d00000000700000077000007007007070700000d000000777770077777000000000000000000000000000000000010000000000000000000000000000000
0077700000000700076070007d07770070070077000d000000077700007770000000000000000000000000000000000007770070000000000000000000000000
0007770000007000700770060707000d7007000070d0000007000000000000700800080008000800080008000800080007007777077707000777007007770700
000777700005700007770677700077700777077700d0000000070700007070000080800000808000008080000080800007007070077777000777770707777700
0000777775d6000000005500000000000007d000000ddd0000000000000000000008000000080000000800000008000000777700077777770777777007777777
00000777777000000050000000070000007700000ddd0d0000000007070000000080800000808000008080000080800000707000007771700077717000777170
0000dd777777600000055ddd000700000707ddddd000d00000007007070070000800080008000800080008000800080007770000077717070777170700771707
000666d777767700000000007dd77dddd7d700000000000000000770007700000000000000000000000000000000000070700000000770000007700007077000
00777500777767700000000707070077077000005000000000000070007000000000000000000000000000000000000007770000000707000007070000700700
07770000077776770000000707070570700000550000000000000000000000000000000000000000000000000000000077707000000000000000000000000000
d7700000007776676005000707007007dddddd000000000008000800080008000800080008000800080008000800080070077700007000700007070000700070
77700077660777667050507706000000000000000000000000808000008080000080800000808000008080000080800070070000000707000007070000070700
77000700006d776676d00077d0000000000000000000000000080000000800000008000000080000000800000008000007700000077771700777717007777170
7700700000076777770ddd7700000077007007600777000000808000008080000080800000808000008080000080800077000000777777007777770077777700
770070007700777667000077000007007070070d7007000008000800080008000800080008000800080008000800080007000000077771700777717007777170
777070007700777667076070007d07007007070077700ddd00000000000000000000000000000000000000000000000000000000000707000007070000070700
777007000600077676700770060707007dd707007000d00d00000000000000000000000000000000000000000000000000000000007000700070007000070700
07770077700007777007770677700077d00d70000777ddd0000000000000000000000000000000000000000000000d0000000000000000000000000000000000
077700000000777760000dddd000000000dd0000000d0000080008000800080008000800080008000800080000000dd000000070000000007750055000d0d000
007770000000777700000d000500000006005000ddd00000008080000080800000808000008080000080800000000ddd0000770000000000777700500ddddd00
0007776000067770000000ddd0500000060005dd00000000000800000008000000080000000800000008000000000dd07007070077707700777777000ddddd00
0000777777777d00000000000dddddddd6dddd0000000000008080000080800000808000008080000080800000000d0007700070000707000077777700ddd000
000000777760000000000000000055000700050000000000080008000800080008000800080008000800080000000000000000000000007005007777000d0000
00000000000000000000000000000055575550000000000000000000000000000000000000000000000000000000000000000000000000000550057700000000
00000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000330000003300000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000033000000330000003b0000003b0000005bb60000000000053500000800080008000800
000000000000000007707700000000000d06600000d6600000660000703b0700003b000070330070003300000035bb0000bb6b006b5000000080800000808000
007007000000000006ccc60007ccc70000cdc00000cdc00000dcc000073b7000003b0000673b0760003b0000050b36600b336b600bb500000008000000080000
000cc000007cc70000dcd00006dcd6000cccc0000cccc0000dccd60000bb000007bb700006bbb60007bbb70000533b000335bb60063033000080800000808000
000cc000000cc00000ccc00000ccc00000cdc60000cdc00000ccc6000033000070330700035b5000765b56700333300003305b0006b333000800080008000800
00000000000000000d0c0d000d0c0d0000d066000d0660000c00d0000000000000000000003330006033306003bb30000005350000b3b0000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000005000500050005000000000000000000000000000000000000000000
00000000000000000000000000000000000000000870800008008770000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000008700080080000807000000000007000000000700000000000000000008000800080008000800080008000800
07828700008280007782877000828000002200007808800008088000070000000007000070077000000000000000000000808000008080000080800000808000
06828600078287006682866077828770082880007888200008882000007700000077000007777000000707700007000000080000000800000008000000080000
008880000688860008282800662826608282880078ee880008ee8800007770000777770000777000007770000777770000808000008080000080800000808000
000000000000000050e8e05050e8e0508888880007eeee0000eeee00000770000007700000777700770700000007000008000800080008000800080008000800
00000000000000000080800000808000827282000202020002020200000007000007000000770070000000000000000000000000000000000000000000000000
00000000000000000000000000000000087800000000000000000000000000000007000007000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000020022000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000066020004440000006602080008000800080008000800080008000800080008000800080008000800080008000800
00000000000000000099900000999000009942400092442200999602008080000080800000808000008080000080800000808000008080000080800000808000
70aa070000aa000022aaa22022aaa22009aa444009a4420009aaa424000800000008000000080000000800000008000000080000000800000008000000080000
0a44a0000a44a0007a444a700a444a0009aa424009aaa96009aaa444008080000080800000808000008080000080800000808000008080000080800000808000
0944900079449700092429006924296009aaa90209aaa96009aaa424080008000800080008000800080008000800080008000800080008000800080008000800
00000000000000000044400070444070009996020099900000999602000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000400040004000400000000000000000000006602000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000500050005000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
005050000050500070aaa07000aaa00000d5a000066a5a0000500d00080008000800080008000800080008000800080008000800080008000800080008000800
075a5700005a5000675a5760005a5000005aaa00566a5aa05aa50550008080000080800000808000008080000080800000808000008080000080800000808000
069a9600079a9700069a9600079a9700000555000a5955a005a95aa0000800000008000000080000000800000008000000080000000800000008000000080000
0055500006555600005550007655567009a9a6600aaa0d5009aa5aa0008080000080800000808000008080000080800000808000008080000080800000808000
00a7a00000a7a00000a9a00060a9a06005a5a6600a59000006a5aa00080008000800080008000800080008000800080008000800080008000800080008000800
000600000006000000575000005750000aaa00005000000006600000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006000000060000500050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000002222200004499000044990004000400000449000033bb3bb3bbbb0000000333b333bb333b33b34444444499999999999999999999999933b3bb33
000000000022242400004499000049440000404900004444000033b33bbbbbbb0000033b3bbbbbbbbbbbbb304442444422222222999999999999999933b33b3b
22222222222242420000494400004499000404490044449900003bb33b3bbb3b000333bbbbbbbbbbb33b3300444444444242424299999999999944993bb3bb33
44444244424244440000449900004449000004440444949900003bbb3b3b3b3b0003bb3bbbbb33b33b333000424442442444242499999999994999993bb33b3b
44444444244424240000449900440494000044994449994900003bbb33bb33bb0033b3bbbbb3bb33333000004444244444444244999999999994444933b33b3b
424444444422444200004449040000490000444944449999000033b3333bb3bb033b33bb3b33333330000000444244422424424499999999999999993bb33b33
444444244444442400004944000000440000094449944499000033bb0333333b3333bbbb33333000000000002422242442442424999999999999999933b3bb33
4444444444444444000044990000000400004499449999990000033b0033b3333b3bbbbb33300000000000002222222244444444999999999999999933b33b3b
33bbb3bb4000449999994400000000000000000000000000043b00000000000000499440000000004949994000000000005050000000000000dddd0000776600
333bb33b94499999994400000000000000000049000000000bb3b000000000000049994004000040449994400000000000050000000000000076dd0007d66dd0
3b3bbb33499999994400000000000000000444990000000000bb30000000000000949940004004004999994000111100000500000000000000066dd0076766d0
3b3bbbb399999944000000000000000000499994000000000000b00000000000004999400049440049999440001111000050500000aaaa00000006d007d76dd0
3333bbb399494400000000000000000049999400000000bb000000000000040000499940004494044999944011111100005050000aaaaaa0007006d006d76dd0
3b33bbb349940000000000000000044499940000000bb330000000000000400000499944004949404499994011111100000500000aaaaaa0006776d00aaaa990
33b33b3b44400000000000000049499994400000004b3bb0000000000044400000499994004999404499994011111111000500000aa999a000066d000aaaa990
33bbb33b400000000000000044999999400000000043bbd00000000044940000004999940049944049999440111111110050500099a9a9a900000000066666d0
8888888888888888888888888888888888888888760d0006d000706d760d0006ddd22ddd0000002d0000002d0000022d002222d602222d6200222d22dd222ddd
022224422222222422444222222222222222242076006006d006006d76aaaaaadd2225dd0000002d0000002d0000022200022d6602252266002222d2222d6622
0222ee22222222e22eee2222222222222222e22076000706d0d0006d76a5555a652222dd0000002d0000002d00000222000252260225d2220222d2d6ddd6226d
0220022222200e22eee00222222002222220022076000066dd00006d76aaaaaa65200256000000220000002d0000025200022d220222d6260225222622d22222
02e002222220022eee2002222220022222e0022076000706d0d0006d76a55a5ad2000025000000220000002d0000002d00002dd2022522620222dd22d2222ddd
0ee22222222e22eee2222222222222222e22222076006006d006006d76aaaaaa520000220000002d000000220000002d000022d600222d6602222666ddd2222d
0e22222222e22eee2222222222222222e2222220760d0006d000706d76aaa55a200000020000000d0000002d0000002d000022220025222602252226222dddd2
888888888888888888888888888888888888888876d00006d000066d76aaaaaa00000000000000020000002d0000002200002d220022ddd60222dd6200022222
dddddddddddddddddddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddddd2ddddddddd22ddddd08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
d22dd6dddddddddddddd55dd00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
d65dd266dddddddd5dd22ddd00080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000
6d25dd22dddddddd25ddddd500808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
d52225ddddddddddd225552d08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
52222222dddddddddd2222dd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222222dddddddddddddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
00080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000
00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
00080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000
00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
00080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000
00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
00080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000000800000008000000080000
00808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000008080000080800000808000
08000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800080008000800
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0106000021530215251d5301d5252d0002d0002f0002f0002d0002d0052d0002d00500000000002d0002d0002b0002b0052b0002b00500000000002b0002b0002a0002a0002a0002a000300002f0002d0002b000
01060000215502b5512b5512b5412b5310d5012900026000215002b5012b5012b5012b5012b50128000240002900024000280000000000000000000000000000000000000000000000000000000000000002d000
0106000021120211151d1201d1152d000280002d0002f000300002f0002d0002b000290002800000000000000000000000000000000000000000000000000000000000000000000000000000000000000002f000
010300001c7301c730186043060524600182001830018300184001840018500185001860018600187001870018200182000000000000000000000000000000000000000000000000000000000000000000000000
010300001873018730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0106000024540245302b5202b54013630136111360100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01060000186701865018620247702b7702b7700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c0000185551c5551f5501f55000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600000c2200c2210c2110c21100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000003065024631186210c61100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

