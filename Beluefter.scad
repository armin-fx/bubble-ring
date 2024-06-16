// Description:
//
// A 3D model for a bubble ring for aquarium.
// For an aquarium air hose with 4mm inner diameter.

/* [ring parameter] */
// inner height without wall
height   =  5;
// diameter (inner or outer diameter of the ring)
diameter = 15;
//
diameter_type = "inner"; // ["inner", outer]
// inner air width
bag      =  2.6;
// wall thickness
wall     =  1.2;
//
hole_type = "hole"; // ["hole", "slot"]
//
hole_place = "inner"; // ["inner", "outer", "both sides", "across", "across shifted"]

/* [hole parameter] */
//
hole_diameter = 1.0; // [1.0, 0.8, 0.61, 0.5, 0.35]
//
hole_ratio    = 2.0; // [0.1 : 0.1 : 10]
//
hole_toggle   = "auto"; // ["auto", "yes", "no"]
//
hole_toggle_ratio = 0.67; // [0 : 0.01: 1]

/* [slot parameter] */
//
slot_width = 0.5; // [1.0, 0.7, 0.5, 0.35, 0.25, 0.175, 0.1]
//
slot_ratio = 2.0; // [0.1 : 0.1 : 10]
//
slot_height_ratio = 1.0; // [0 : 0.01 : 1]

/* [accuracy] */
// multiplicated with 12
fn_factor=4;
//
slicer_steg = "no"; // ["no", "yes", "cut"]

/* [Hidden] */

include <banded.scad>
required_version ([3,0,0]);

diameter_inner =
	diameter_type=="inner"
		? diameter
		: diameter - 2 * (bag + 2*wall)
;
//
hole_cnt   = hole_ratio * (sqr(3.0) / sqr(hole_diameter));
hole_cnt_q = quantize(hole_cnt,  1);
//
hole_inner_cnt    = balance_holes(hole_cnt_q) [0];
hole_outer_cnt    = balance_holes(hole_cnt_q) [1];
hole_inner_count  = get_hole_count(hole_inner_cnt);
hole_outer_count  = get_hole_count(hole_outer_cnt);
//
hole_toggle_inner = is_hole_toggle(hole_inner_count);

//
slot_cnt = slot_ratio * ( (sqr(3.0)*PI/4) /
	((sqr(slot_width)*PI/4) + (height-slot_width)*slot_width*slot_height_ratio) );
slot_cnt_q = quantize(slot_cnt, 1);
//
slot_inner_count = balance_holes(slot_cnt_q) [0];
slot_outer_count = balance_holes(slot_cnt_q) [1];

//
fn_hole_inner = get_best_fit_fn( get_hole_pos_count(hole_inner_count) );
fn_slot_inner = get_best_fit_fn( slot_inner_count );
fn_inner =
	(hole_type=="hole") ? fn_hole_inner :
	(hole_type=="slot") ? fn_slot_inner :
	12*fn_factor
;
fn_hole_outer = get_best_fit_fn( get_hole_pos_count(hole_outer_count) );
fn_slot_outer = get_best_fit_fn( slot_outer_count );
fn_outer =
	(hole_type=="hole") ? fn_hole_outer :
	(hole_type=="slot") ? fn_slot_outer :
	12*fn_factor
;

//
function get_best_fit_fn (count) =
	(count>0) ?
		min( [for (n=[fn_factor:1:fn_factor+count]) kgv(count, 12*n)] )
	:	12*fn_factor
;
//
function get_hole_count (value) = get_hole_count_intern(quantize(value,1));
function get_hole_count_intern (count) =
	(count < 30 || (hole_place=="across")) ? count : quantize(count,2)
;
function get_hole_pos_count (count) =
	(is_hole_toggle(count) && is_odd(count)) ?
	 count+1
	:count
;
function is_hole_toggle (count) =
	( hole_toggle=="yes") ? true
	:(hole_toggle=="no" ) ? false
	:(hole_toggle=="auto") ?
		(count < 6) ? false : true
	:false
;
// returns: [inner, outer]
function balance_holes (count) =
	 (hole_place=="inner") ? [quantize(count,1), 0]
	:(hole_place=="outer") ? [0, quantize(count,1)]
	:(hole_place=="both sides") ?
		[quantize( count * ( (diameter_inner/2+wall/2)   / ((diameter_inner/2+wall/2)+(diameter_inner/2+wall+bag)) ), 1)
		,quantize( count * ( (diameter_inner/2+wall+bag) / ((diameter_inner/2+wall/2)+(diameter_inner/2+wall+bag)) ), 1) ]
	:(hole_place=="across")         ? [      quantize(count,2)/2, quantize(count,2)/2]
	:(hole_place=="across shifted") ? [count-quantize(count,2)/2, quantize(count,2)/2]
	:[0,0]
;

combine_fixed()
{
	Luefter_Ring();
	
	pos_tuelle = [(diameter_inner+max(5.0,bag+2*wall))/2, 0, height];
	//
	union ()
	{
		fn_tuelle = fn_factor*12;
		translate(pos_tuelle) Tuelle_Schaft(height=6, $fn=fn_tuelle); translate_z(6)
		translate(pos_tuelle) Tuelle_Ende  (height=4, $fn=fn_tuelle);
		//
		if (norm([pos_tuelle[0], pos_tuelle[1]]) > diameter_inner/2 +wall+bag+wall - 5.0/2)
			render()
			difference()
			{
				d=5.0;
				translate(pos_tuelle) translate_z(-d)
				cylinder(h=d, d1=d/2, d2=d, $fn=fn_tuelle);
				//
				translate_z(-extra)
				cylinder(h=height+extra, r=diameter_inner/2+wall+bag+wall-epsilon, $fn=fn_outer);
			}
	}
	
	render()
	translate(pos_tuelle) Tuelle_Schaft_cut($fn=fn_factor*12);
}

if      (hole_type=="hole")
{
echo (str("holes all:         \t", hole_cnt_q, " (", hole_cnt, ")"));
echo (str("holes inner/outer: \t", hole_inner_count, " / ", hole_outer_count));
}
else if (hole_type=="slot")
{
echo (str("slots all:         \t", slot_cnt_q, " (", slot_cnt, ")"));
echo (str("slots inner/outer: \t", slot_inner_count, " / ", slot_outer_count));
}
echo (str("$fn inner/outer:   \t", fn_inner, " / ", fn_outer, "  (",12*fn_factor,")"));

module Luefter_Ring ()
{
	difference()
	{
		// Grundkörperwand innen
		tube(h=height, di=diameter_inner, w=wall, $fn=fn_inner);
		
		// Löcher
		if (hole_type=="hole")
		{
			create_hole(hole_inner_count, diameter_inner/2+wall+extra, 0,
				swap_toggle=(hole_place=="across shifted") ? true : false );
		}
		else if (hole_type=="slot")
		{
			create_slot(slot_inner_count, diameter_inner/2+wall+extra, 0,
				drift= (hole_place=="both sides"||hole_place=="across shifted") ? 0.5 : 0 );
		}
	}
	
	difference()
	{
		// Grundkörperwand außen
		tube(h=height, di=diameter_inner+2*(wall + bag), w=wall, $fn=fn_outer);
		
		// Löcher
		if (hole_type=="hole")
		{
			create_hole(hole_outer_count, bag+wall, diameter_inner/2+wall+extra,
				drift= (hole_place=="across shifted" && !is_hole_toggle(hole_outer_count)) ? 0.5 : 0 );
		}
		if (hole_type=="slot")
		{
			create_slot(slot_outer_count, bag+wall, diameter_inner/2+wall+extra);
		}
	}
	
	// Boden unten und oben
	difference()
	{
		mirror_copy_at([0,0,1], [0,0,height/2])
			Luefter_Ring_top();
		
		// Stege für den Slicer ausschneiden
		if (slicer_steg=="cut")
		{
			s_wall   = 1.4;
			s_gap    = 0.1;
			s_height = 0.125;
			s_count  = round((diameter_inner+wall*2+bag)*PI / (s_wall+s_gap));
			render()
			for (a=[0 : 360/s_count : 360-epsilon])
				rotate_z(a)
				translate([diameter_inner/2+wall, -s_gap/2, height-extra])
				cube([bag, s_gap, s_height+extra])
			;
		}
	}
	
	// Stege für den Slicer hinzufügen
	if (slicer_steg=="yes")
	{
		s_wall   = 1.0;
		s_gap    = 0.5;
		s_height = 0.1;
		s_count  = round((diameter_inner+wall*2+bag)*PI / (s_wall+s_gap));
		for (a=[0 : 360/s_count : 360-epsilon])
			rotate_z(a)
			translate([diameter_inner/2+wall-wall/2, -s_wall/2, height-s_height])
			cube([bag+wall, s_wall, s_height])
		;
	}
}

module create_hole (count, depth, pos, drift=0, swap_toggle=false)
{
	translate_z(height/2)
	for (n=
		is_hole_toggle(count) ?
		is_odd(count) ? 
			 [1 : 1 : get_hole_pos_count(count)-epsilon]
			:[0 : 1 : get_hole_pos_count(count)-epsilon]
		:    [0 : 1 : get_hole_pos_count(count)-epsilon]
	)
		translate_z(
			(height*hole_toggle_ratio/2-hole_diameter/2)
			* (is_odd(n)             ?  1 : -1)
			* (swap_toggle           ? -1 :  1)
			* (is_hole_toggle(count) ?  1 :  0)
		)
		rotate_z(360*(n+drift)/get_hole_pos_count(count))
		rotate_y(90)
		translate_z(pos)
		cylinder(h=depth, d=hole_diameter, $fn=6*fn_factor)
		;
}

module create_slot (count, depth, pos, drift=0)
{
	translate_z ( (1-slot_height_ratio) * (height-slot_width) / 2 )
	mirror_z()
	for(n=[0 : 1 : count-epsilon])
		rotate_z(360*(n+0.5+drift)/count)
		render()
		rotate_y(90)
		translate_z(pos)
		if (slot_height_ratio > 0) union()
		{
			translate([+slot_width/2+epsilon,0,0])
			cylinder(h=depth, d=slot_width, $fn=6*fn_factor);
			//
			translate([+slot_width/2+epsilon,-slot_width/2,0])
			cube([slot_height_ratio*(height-slot_width)-epsilon*2, slot_width, depth]);
			//
			translate([slot_height_ratio*(height-slot_width)+slot_width/2-epsilon,0,0])
			cylinder(h=depth, d=slot_width, $fn=6*fn_factor);
		}
		else
		{
			translate([+slot_width/2+epsilon,0,0])
			cylinder(h=depth, d=slot_width, $fn=6*fn_factor);
		}
}

module Luefter_Ring_top ()
{
	// Scheibe
	difference()
	{
		translate_z(-wall)       cylinder(h=wall        , r=diameter_inner/2+wall+bag, $fn=fn_outer);
		translate_z(-wall-extra) cylinder(h=wall+extra*2, r=diameter_inner/2+wall    , $fn=fn_inner);
	}
	// Rundungen
	rotate_extrude(convexity=4, $fn=fn_inner)
	polygon( concat(
		translate_points (
			circle_curve(r=wall, angle=[90, 180], piece=false, $fn=8*fn_factor)
			,[diameter_inner/2+wall,0])
		,[[diameter_inner/2+wall+epsilon,0]]
	));
	rotate_extrude(convexity=4, $fn=fn_outer)
	polygon( concat(
		translate_points (
			circle_curve(r=wall, angle=[90, 270], piece=false, $fn=8*fn_factor)
			,[diameter_inner/2+wall+bag,0])
		,[[diameter_inner/2+wall+bag-epsilon,0]]
	));
}

module Luefter_Ring_top_old ()
{
	rotate_extrude(convexity=4)
	polygon( concat(
		translate_points (
			circle_curve(r=wall, angle=[90, 180], piece=false, $fn=8*fn_factor)
			,[diameter_inner/2+wall,0])
		,
		translate_points (
			circle_curve(r=wall, angle=[90, 270], piece=false, $fn=8*fn_factor)
			,[diameter_inner/2+wall+bag,0])
	));
}

module Tuelle_Ende (height=4, diameter=5.0, wall=1, seal=0.07)
{
	r_round    = 0.5;
	height_real= height-r_round;
	seal_ratio = 1/5;
	seal_angle = atan((seal_ratio*height_real)/seal);
	//
	mirror_at([0,0,1], [0,0,height/2])
	rotate_extrude(convexity=4)
	polygon( concat(
		[[diameter/2-wall,0]
		//,[diameter/2-r_round,0]
		]
		,translate_points(
			circle_curve(r=r_round, angle=[seal_angle, 270], piece=false, $fn=$fn/2)
			,[diameter/2-r_round,r_round])
		,[//[diameter/2,r_round],
		  [diameter/2+seal,height_real*   seal_ratio +r_round-r_round*cos(seal_angle)]
		 ,[diameter/2+seal,height_real*(1-seal_ratio)+r_round-r_round*cos(seal_angle)]
		 ,[diameter/2,height]
		 ,[diameter/2-wall,height]
		 ,[diameter/2-wall,0]
		]
	));
}

module Tuelle_Schaft (height=10, diameter=5.0, wall=1)
{
	tube(h=height, do=diameter, w=wall);
}

module Tuelle_Schaft_cut (height=10, diameter=5.0, wall=1)
{
	d=diameter-wall*2;
	union()
	{
		cylinder(h=height+extra, d=d);
		translate_z(-d)
		cylinder(h=d, d1=d/2, d2=d);
	}
}
