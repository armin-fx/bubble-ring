include <tools.scad>

/* [ring parameter] */
// inner height without wall
height   =  5;
// inner diameter
diameter = 15;
// inner air width
bag      =  2.5;
//
wall     =  1.5;
//
hole_type = "hole"; // ["hole", "slot"]
//
hole_place = "inner"; // ["inner", "outer", "both_sides", "across"]

/* [hole parameter] */
//
hole_diameter = 1.0; // [1.0, 0.8, 0.61, 0.5, 0.35]
//
hole_ratio    = 1.0; // [0.1 : 0.05 : 5]
//
hole_toggle_ratio = 0.67; // [0 : 0.01: 1]

/* [slot parameter] */
//
slot_width = 0.5; // [1.0, 0.7, 0.5, 0.35, 0.25, 0.175, 0.1]
//
slot_ratio = 2.0; // [0.1 : 0.1 : 10]

/* [accuracy] */
// multiplicated with 12
fn_factor=4;
//
slicer_steg = "no"; // ["no", "yes", "cut"]

/* [Hidden] */

//
hole_cnt = hole_ratio * (sqr(3.0) / sqr(hole_diameter));
hole_cnt_q = quantize(hole_cnt,  1);
hole_inner_cnt1 = quantize(hole_cnt,  1);
hole_inner_cnt2 = quantize(hole_inner_cnt1, 2);
hole_inner_count  = (hole_inner_cnt1 < 30) ? hole_inner_cnt1 : hole_inner_cnt2;
hole_inner_countX = (hole_inner_cnt1 <  6) ? hole_inner_cnt1 : hole_inner_cnt2;

//
slot_cnt = slot_ratio * ( (sqr(3.0)*PI/4) /
                         ((sqr(slot_width)*PI/4) + (height-slot_width)*slot_width));
slot_inner_count = quantize(slot_cnt, 1);

//
fn_hole_inner=[for (n=[fn_factor:1:fn_factor+hole_inner_countX]) kgv(hole_inner_countX,12*n)];
fn_slot_inner=[for (n=[fn_factor:1:fn_factor+slot_inner_count ]) kgv(slot_inner_count ,12*n)];
fn_inner = min(
	(hole_type=="hole") ? fn_hole_inner :
	(hole_type=="slot") ? fn_slot_inner :
	12*fn_factor
);
fn_hole_outer = 12*fn_factor;
fn_slot_outer = 12*fn_factor;
fn_outer = min(
	(hole_type=="hole") ? fn_hole_outer :
	(hole_type=="slot") ? fn_slot_outer :
	12*fn_factor
);


build()
{
	Luefter_Ring();
	
	pos_tuelle = [(diameter+max(5.0,bag+2*wall))/2, 0, height];
	//
	union ()
	{
		fn_tuelle = fn_factor*12;
		translate(pos_tuelle) Tuelle_Schaft(height=6, $fn=fn_tuelle); translate_z(6)
		translate(pos_tuelle) Tuelle_Ende  (height=4, $fn=fn_tuelle);
		//
		if (norm([pos_tuelle[0], pos_tuelle[1]]) > diameter/2 +wall+bag+wall - 5.0/2)
			render()
			difference()
			{
				d=5.0;
				translate(pos_tuelle) translate_z(-d)
				cylinder(h=d, d1=d/2, d2=d, $fn=fn_tuelle);
				//
				translate_z(-extra)
				cylinder(h=height+extra, r=diameter/2+wall+bag+wall-epsilon, $fn=fn_outer);
			}
	}
	
	render()
	translate(pos_tuelle) Tuelle_Schaft_cut($fn=fn_factor*12);
}

if      (hole_type=="hole")
echo (str("Löcher:  \t", hole_inner_count, " / ", hole_inner_cnt2, " (", hole_cnt, ")"));
else if (hole_type=="slot")
echo (str("Schlitze: \t", slot_inner_count, " (", slot_cnt, ")"));
echo (str("$fn_inner:\t", fn_inner, " (",12*fn_factor,")"));
echo (str("$fn_outer:\t", fn_outer, " (",12*fn_factor,")"));

module Luefter_Ring ()
{
	difference()
	{
		// Grundkörperwand innen
		ring_square(h=height, di=diameter, w=wall, $fn=fn_inner);
		
		// Löcher
		if (hole_type=="hole")
		{
			translate_z(height/2)
			for (n=[(is_even(hole_inner_count)||(hole_inner_count<6) ? 0 : 1) : 1 : hole_inner_countX-epsilon])
				translate_z(
					(height*hole_toggle_ratio/2-hole_diameter/2)
					* (is_odd(n)    ? 1 : -1)
					* (hole_inner_count<6 ? 0 :  1)
				)
				rotate_z(360*n/hole_inner_countX)
				rotate_y(90)
				cylinder(h=diameter/2+wall+extra, d=hole_diameter, $fn=6*fn_factor)
			;
		}
		else if (hole_type=="slot")
		{
			for(n=[0 : 1 : slot_inner_count-epsilon])
				rotate_z(360*(n+0.5)/slot_inner_count)
				mirror([0,0,1]) rotate_y(90)
				union()
				{
					translate([+slot_width/2+epsilon,0,0])
					cylinder(h=diameter/2+wall+extra, d=slot_width, $fn=6*fn_factor);
					//
					translate([+slot_width/2+epsilon,-slot_width/2,0])
					cube([height-slot_width-epsilon*2, slot_width, diameter/2+wall+extra]);
					//
					translate([height-slot_width/2-epsilon,0,0])
					cylinder(h=diameter/2+wall+extra, d=slot_width, $fn=6*fn_factor);
				}
			;
		}
	}
	
	// Grundkörperwand außen
	ring_square(h=height, di=diameter+2*(wall + bag), w=wall, $fn=fn_outer);
	
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
			s_count  = round((diameter+wall*2+bag)*PI / (s_wall+s_gap));
			for (a=[0 : 360/s_count : 360-epsilon])
				rotate_z(a)
				translate([diameter/2+wall, -s_gap/2, height-extra])
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
		s_count  = round((diameter+wall*2+bag)*PI / (s_wall+s_gap));
		for (a=[0 : 360/s_count : 360-epsilon])
			rotate_z(a)
			translate([diameter/2+wall-wall/2, -s_wall/2, height-s_height])
			cube([bag+wall, s_wall, s_height])
		;
	}
}

module Luefter_Ring_top ()
{
	// Scheibe
	difference()
	{
		translate_z(-wall)       cylinder(h=wall        , r=diameter/2+wall+bag, $fn=fn_outer);
		translate_z(-wall-extra) cylinder(h=wall+extra*2, r=diameter/2+wall    , $fn=fn_inner);
	}
	// Rundungen
	rotate_extrude(convexity=4, $fn=fn_inner)
	polygon( concat(
		translate_list ([diameter/2+wall,0],
			circle_curve(r=wall, angle=90, angle_begin=180, piece=false, $fn=8*fn_factor))
		,[[diameter/2+wall+epsilon,0]]
	));
	rotate_extrude(convexity=4, $fn=fn_outer)
	polygon( concat(
		translate_list ([diameter/2+wall+bag,0],
			circle_curve(r=wall, angle=90, angle_begin=270, piece=false, $fn=8*fn_factor))
		,[[diameter/2+wall+bag-epsilon,0]]
	));
}

module Luefter_Ring_top_old ()
{
	rotate_extrude(convexity=4)
	polygon( concat(
		translate_list ([diameter/2+wall,0],
			circle_curve(r=wall, angle=90, angle_begin=180, piece=false, $fn=8*fn_factor))
		,
		translate_list ([diameter/2+wall+bag,0],
			circle_curve(r=wall, angle=90, angle_begin=270, piece=false, $fn=8*fn_factor))
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
		,translate_list([diameter/2-r_round,r_round],
			circle_curve(r=r_round, angle=seal_angle, angle_begin=270, piece=false, $fn=$fn/2))
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
	ring_square(h=height, do=diameter, w=wall);
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
