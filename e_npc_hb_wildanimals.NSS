// e_npc_hb_wildanimals
/*
	Gets animals to escape whoever approaches
	
*/
// 1106 Alban


#include "ginc_debug"
#include "inc_vectors"
#include "X0_I0_POSITION"




const float DISTANCE_FLEE				= 33.0; // Used to search flee location
const float DISTANCE_SAFE				= 65.0; // Used to consider safe
const int S_MAX_LOC_SEARCH_DEPTH		= 13; 	// Defines the search depth
const float SEARCH_INCREMENT_DIST 		= 2.0;	// Search iterations parameter
const float SEARCH_INCREMENT_ANGLE 		= 44.0;	// Search iterations parameter
const int SWITCH_FLEE_HALF_ROUND		= TRUE;	// Set to FALSE for 50% less script usage


// Returns a distance that's considered harmless.
// Could use specific data : area size, creature type etc.
float GetSafeDistance( object oCreature ) {

	object oArea 			= GetArea( oCreature );
	
	if( ! GetIsAreaInterior( oArea ) ) return DISTANCE_FLEE;
	
	return DISTANCE_SAFE;
	
//	float fDist = 6.0 * sqrt( IntToFloat( GetAreaSize( AREA_HEIGHT, oArea ) * GetAreaSize( AREA_WIDTH, oArea ) ) )  ;
//	return fDist;
	

}


// Used by GetValidFleeLocation
location GetFleeLocation( object oCreature, object oTarget, float fDist, float fOptionalAngle = 0.0 ) {

	float fAngle 			= GetAngleBetweenObjects( oTarget , oCreature ) + Random( 45 ) + fOptionalAngle;
	//
	vector vRef 			= GetPosition( oCreature );
	//
	vector vPosition 		=   VAtAngleToV( vRef, fDist, fAngle); 
	//
	location lFlee 			= Location( GetArea( oCreature ), vPosition, fAngle );
	//
	//DebugLocation( lFlee, "blue" );
	return lFlee;
	
}


// The workhorse of flee position search
location GetValidFleeLocation( object oCreature, object oTarget ) {

	int nSearchDepth;

	float fDepthParam;

	float fDist 		=DISTANCE_FLEE;

	float fOptAngle = -SEARCH_INCREMENT_ANGLE;

	location lFlee 	;
	
	while( ! GetIsLocationValid( lFlee ) && nSearchDepth < S_MAX_LOC_SEARCH_DEPTH ) {

		nSearchDepth++;
		//

		fDepthParam 	-= SEARCH_INCREMENT_DIST;
		//
		fOptAngle 		+= SEARCH_INCREMENT_ANGLE;
		//
		lFlee = GetFleeLocation( oCreature, oTarget, fDist + fDepthParam, fOptAngle + fDepthParam );
 		//PrettyDebug("() GetValidFleeLocation : SearchDist " + FloatToString( fDist + fDepthParam ) + " fOptAngle " + FloatToString( fOptAngle ) + " fDepthParam " +  FloatToString( fDepthParam ) + " nSearchDepth " + IntToString( nSearchDepth )  );		
	}
	
	return lFlee;
}


// Encapsulates search + locomotion
int ActionFlee( object oCreature, object oTarget = OBJECT_INVALID ) {

	
	location lFlee = GetValidFleeLocation( oCreature, oTarget );
		
	if( 	GetDistanceBetweenLocations( GetLocation( oTarget ), lFlee ) 
		< 	GetDistanceBetweenLocations( GetLocation( oTarget ), GetLocation( oCreature ) ) )
		
		return FALSE;
	
	object oWaypoint = CreateObject( OBJECT_TYPE_WAYPOINT, "nw_waypoint001", lFlee, FALSE );
	//
	AssignCommand( oCreature, ActionForceMoveToObject( oWaypoint, TRUE ) );
	//
	DestroyObject( oWaypoint, 6.5);
	//
	//PrettyDebug("()	ActionFlee : " + GetName( oCreature ) +" looked for a way out " );
	return TRUE;
	
}

// Simple encapsulation 
void DelayActionFlee(  object oCreature, object oTarget = OBJECT_INVALID ) {

	ActionFlee( oCreature, oTarget ); 

}

// Checks some conditions to react adequately
int GetIsInteractionCreatureValid( object oTarget ) {

	 int nHP = GetCurrentHitPoints( oTarget );
	
	 // We don't flee safe NPCs / animals
	if( !GetIsPC( oTarget ) && GetSubRace(oTarget) == RACIAL_SUBTYPE_ANIMAL && !GetIsReactionTypeHostile ( oTarget ) ){
			//PrettyDebug("() GetIsTargetValid : "+GetName(oTarget)+" is an Animal " );
		return FALSE;
	}
	// We don't flee what is not valid or harmful
	if( !GetIsObjectValid( oTarget ) || GetIsDead( oTarget )){
			//PrettyDebug("() GetIsTargetValid : Invalid Target " );
		return FALSE;
	}
	// We don't flee what is dying
	if ( nHP < 1 ) {
			//PrettyDebug("() GetIsTargetValid : Target HP ( " + IntToString( nHP ) + " ) < 1 " );
		return FALSE;
	}

	 //PrettyDebug("() GetIsTargetValid : Valid Target " );
	 return TRUE;
}

void main() {
	
	object oNPC				= OBJECT_SELF;
	
	object oTarget;
	
	float fDist				= 0.0;
	
	float fMin 				= 9999.9;
	
	int nNth 				= 1;
	
	object oCreature = GetNearestCreature( CREATURE_TYPE_IS_ALIVE, CREATURE_ALIVE_TRUE, oNPC, nNth );
	
	while( GetIsObjectValid( oCreature ) ) {
	
		//PrettyDebug("I've spotted " + GetName( oCreature )+" at "+FloatToString(GetDistanceBetween( oNPC, oCreature ))+"m" );

		// Assign target if valid
		if( GetIsInteractionCreatureValid( oCreature ) ) {
	
			fDist			= GetDistanceBetween( oNPC, oCreature );
			//PrettyDebug(GetName( oCreature )+":"+FloatToString(fDist)+"vs"+FloatToString(fMin)+"/"+FloatToString( GetSafeDistance( oNPC ) ) );
			if( fDist < fMin  && fDist < GetSafeDistance( oNPC ) ) {
				//PrettyDebug(GetName( oCreature )+" is close enough "); 
				fMin		= fDist;
				oTarget		= oCreature;
			}
		}
	
		// Searching too far is unnecessary
		if( fDist < GetSafeDistance( oNPC ) ){
			oCreature = GetNearestCreature( CREATURE_TYPE_IS_ALIVE, CREATURE_ALIVE_TRUE, oNPC, ++nNth );
		} else {
			oCreature = OBJECT_INVALID;
		}
		
	}
	
	// Nothing to flee from ? Quit.
	if( !GetIsObjectValid( oTarget ) ) 	return; // There might be no PC to flee from. Causes DIVIDE BY ZERO if removed

	// Flee!
	//PrettyDebug("I'm Fleeing from " + GetName( oTarget ) );
	ActionFlee( oNPC, oTarget );
	
	if( SWITCH_FLEE_HALF_ROUND ){
		DelayCommand(3.0f, AssignCommand( oNPC, DelayActionFlee( oNPC, oTarget ) ) );
	}

}