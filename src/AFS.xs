/***********************************************************************
 *
 * AFS.xs - AFS extensions for Perl
 *
 * RCS-Id: @(#)AFS.xs,v 2.0 2002/07/02 06:10:23 nog Exp
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the same terms as Perl itself.
 *
 * Copyright (c) 2001-2002 Norbert E. Gruener <nog@MPA-Garching.MPG.de>
 * Copyright (c) 1994 Board of Trustees, Leland Stanford Jr. University
 *
 * The original library is covered by the following copyright:
 *
 *    Redistribution and use in source and binary forms are permitted
 *    provided that the above copyright notice and this paragraph are
 *    duplicated in all such forms and that any documentation,
 *    advertising materials, and other materials related to such
 *    distribution and use acknowledge that the software was developed
 *    by Stanford University.  The name of the University may not be used 
 *    to endorse or promote products derived from this software without 
 *    specific prior written permission.
 *    THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 *    IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 *    WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 ***********************************************************************/

#include "EXTERN.h"

#ifdef __sgi /* needed to get a clean compile */
#include <setjmp.h>
#endif

#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <afs/param.h>
/* tired of seeing messages about TRUE/FALSE being redefined in rx/xdr.h */
#undef TRUE
#undef FALSE
#include <rx/xdr.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <netdb.h>
#include <errno.h>
#include <stdio.h>
#include <netinet/in.h>
#include <sys/stat.h>
#include <afs/stds.h>
#include <afs/afs.h>
#include <afs/afsint.h>
#include <afs/vice.h>
#include <afs/venus.h>
#undef VIRTUE
#undef VICE
#include "afs/prs_fs.h"

#include <afs/auth.h>
#include <afs/cellconfig.h>
#if defined(AFS_3_4)
#else
#include <afs/dirpath.h>
#endif
#include <ubik.h>
#include <rx/rxkad.h>
#include <afs/vldbint.h>
#include <afs/volser.h>
#include <afs/vlserver.h>
#include <afs/cmd.h>
#include "afs/prclient.h"
#include <afs/prerror.h>
#include <afs/print.h>
#include <afs/kauth.h>
#include <afs/kautils.h>
#include <des.h>

#if defined(AFS_3_4) || defined(AFS_3_5)
#else
#define int32 afs_int32
#define uint32 afs_uint32
#endif

const char * const xs_version = "AFS.xs (2.0)";

/* here because it seemed too painful to #define KERNEL before #inc afs.h */
struct VenusFid {
    int32 Cell;	
    struct AFSFid Fid;
};

/* tpf nog 03/29/99 */
/* the following was added by leg@andrew, 10/9/96 */ 
/*#ifdef __hpux /* only on hp700_ux90 systems */
#if defined(__hpux) || defined(_AIX) || defined(sun) || defined(__sun__) || defined(__sgi) || defined(__linux)
static int32 name_is_numeric(char *);
#endif

typedef struct ubik_client *AFS__PTS;
typedef SV *AFS__ACL;
typedef struct ktc_principal *AFS__KTC_PRINCIPAL;
typedef struct ktc_token *AFS__KTC_TOKEN;
typedef struct ubik_client *AFS__KAS;
typedef struct ktc_encryptionKey *AFS__KTC_EKEY;

static struct ktc_token the_null_token;

static int32 convert_numeric_names = 1;

#define      MAXSIZE 2048
#define MAXINSIZE 1300

#ifndef MAXPATHLEN
#define MAXPATHLEN 1024
#endif


#define SETCODE(code) set_code(code)

#define FSSETCODE(code) {if (code == -1) set_code(errno); else set_code(code);}

static int32 raise_exception = 0;

static void
set_code(code)
int32 code;
{
  SV *sv = perl_get_sv("AFS::CODE",TRUE);
  sv_setiv(sv,(IV)code); 
  if (code==0) {
     sv_setpv(sv,"");
  } else {
     if (raise_exception) {
         char buffer[1024];
         sprintf(buffer,"AFS exception: %s (%d)",error_message(code),code);
         croak(buffer);
     }
     sv_setpv(sv,(char*)error_message(code));
  }
  SvIOK_on(sv);
}

static int32
not_here(s)
char *s;
{
    croak("%s not implemented on this architecture or under this AFS version", s);
    return -1;
}

/* return 1 if path is in /afs */
static int32 isafs(path,follow)
char *path; 
int32 follow;
{
    struct ViceIoctl vi;
    register int32 code;
    char space[MAXSIZE];

    vi.in_size = 0;
    vi.out_size = MAXSIZE;
    vi.out = space;

    code = pioctl(path, VIOC_FILE_CELL_NAME, &vi, follow);
    if (code) {
	if ((errno == EINVAL) || (errno == ENOENT)) return 0;
    }
    return 1;
}

static void stolower(s)
char *s;
{
    while (*s) {
	if (isupper(*s)) *s = tolower(*s);
	s++;
    }
}


static struct afsconf_dir *cdir=NULL;
static char *config_dir = NULL;

static int32
internal_GetConfigDir()
{
  if (cdir == NULL ) {

   if (config_dir == NULL) {
#if defined(AFS_3_4)
      config_dir = (char*) safemalloc(strlen(AFSCONF_CLIENTNAME)+1);
      strcpy(config_dir, AFSCONF_CLIENTNAME);
#else
      config_dir = (char*) safemalloc(strlen(AFSDIR_CLIENT_ETC_DIRPATH)+1);
      strcpy(config_dir, AFSDIR_CLIENT_ETC_DIRPATH);
#endif
   }

   cdir = afsconf_Open(config_dir);
   if (!cdir) { return errno; }
  }
  return 0;
}


static int32 
internal_GetCellInfo(cell,service,info)
char *cell;
char *service;
struct afsconf_cell *info;
{
  int32 code;

  code = internal_GetConfigDir();
  if (code==0) code = afsconf_GetCellInfo(cdir, cell, service, info);
  return code;
}

static char *
internal_GetLocalCell(code)
int32 *code;
{

  static char localcell[MAXCELLCHARS]="";

  if (localcell[0]) {
      *code = 0;
  } else {
     *code = internal_GetConfigDir();
     if (*code==0) 
        *code = afsconf_GetLocalCell(cdir, localcell, sizeof(localcell));
  }
  return localcell;
}

static struct ubik_client *
internal_pts_new(code, sec, cell)
int32 *code;
int32 sec;
char *cell;
{
  struct rx_connection *serverconns[MAXSERVERS];
  struct rx_securityClass *sc;
  struct ktc_token token;
  struct afsconf_cell info;
/*  tpf nog 03/29/99
 *  caused by changes in ubikclient.c,v 2.20 1996/12/10 
 *            and     in ubikclient.c,v 2.24 1997/01/21
 * struct ubik_client *client;                             */
  struct ubik_client *client = 0; 
  struct ktc_principal prin;
  int32 i;


  *code = internal_GetConfigDir();
  if (*code==0) *code = internal_GetCellInfo(cell,"afsprot",&info);

  if (*code) return NULL;

  *code = rx_Init(0);
  if (*code) return NULL;

  if (sec > 0) {
        strcpy(prin.cell,info.name);
	prin.instance[0] = 0;
	strcpy(prin.name, "afs");
	*code = ktc_GetToken(&prin,&token, sizeof(token), (char *)0);
	if (*code) {
          if ( sec == 2) return NULL; /* we want security or nothing */
          sec = 0;
	} else {
	  sc = (struct rx_securityClass *) rxkad_NewClientSecurityObject
		(rxkad_clear, &token.sessionKey, token.kvno,
		 token.ticketLen, token.ticket);
	}
    } 

    if (sec==0) 
         sc = (struct rx_securityClass *) rxnull_NewClientSecurityObject();
    else 
         sec=2;

    bzero (serverconns, sizeof(serverconns));
    for (i = 0; i<info.numServers; i++) {
	serverconns[i] = rx_NewConnection (info.hostAddr[i].sin_addr.s_addr, 
                                  info.hostAddr[i].sin_port,PRSRV, sc, sec);
    }

    *code = ubik_ClientInit(serverconns, &client);
    if (*code) return NULL; 

    *code = rxs_Release (sc); 
    return client;
}

static int32 internal_pr_name(server,id,name)
int32 id;
struct ubik_client *server;
char *name;
{
    namelist lnames;
    idlist lids;
    register int32 code;

    lids.idlist_len = 1;
    lids.idlist_val = (int32 *)safemalloc(sizeof(int32));
    *lids.idlist_val = id;
    lnames.namelist_len = 0;
    lnames.namelist_val = NULL;
    code = ubik_Call(PR_IDToName,server,0,&lids,&lnames);
    if (lnames.namelist_val) {
        strncpy(name,(char *)lnames.namelist_val,PR_MAXNAMELEN);
	safefree(lnames.namelist_val);
    }
    if (lids.idlist_val) safefree(lids.idlist_val);
    return code;
}

static int32 internal_pr_id(server,name,id, anon)
struct ubik_client *server;
char *name;
int32 *id;
int32 anon;
{
    namelist lnames;
    idlist lids;
    int32 code;

    if (convert_numeric_names && name_is_numeric(name)) {
        *id = atoi(name);
	return 0;
    }

    lids.idlist_len = 0;
    lids.idlist_val = 0;
    lnames.namelist_len = 1;
    lnames.namelist_val = (prname *)safemalloc(PR_MAXNAMELEN);
    stolower(name);
    strncpy((char *)lnames.namelist_val,name,PR_MAXNAMELEN);
    code = ubik_Call(PR_NameToID,server,0,&lnames,&lids);
    if (lids.idlist_val) {
	*id = *lids.idlist_val;
	safefree(lids.idlist_val);
    }
    if (lnames.namelist_val) safefree(lnames.namelist_val);

    if (code==0 && *id == ANONYMOUSID) {
          code = PRNOENT;
    }

    return code;
}

static char *
format_rights(rights)
int32 rights;
{
  static char buff[32];
  char *p;

  p=buff;

  if (rights & PRSFS_READ)       { *p++ = 'r'; }
  if (rights & PRSFS_LOOKUP)     { *p++ = 'l'; }
  if (rights & PRSFS_INSERT)     { *p++ = 'i'; }
  if (rights & PRSFS_DELETE)     { *p++ = 'd'; }
  if (rights & PRSFS_WRITE)      { *p++ = 'w'; }
  if (rights & PRSFS_LOCK)       { *p++ = 'k'; }
  if (rights & PRSFS_ADMINISTER) { *p++ = 'a'; }
  if (rights & PRSFS_USR0)       { *p++ = 'A'; }
  if (rights & PRSFS_USR1)       { *p++ = 'B'; }
  if (rights & PRSFS_USR2)       { *p++ = 'C'; }
  if (rights & PRSFS_USR3)       { *p++ = 'D'; }
  if (rights & PRSFS_USR4)       { *p++ = 'E'; }
  if (rights & PRSFS_USR5)       { *p++ = 'F'; }
  if (rights & PRSFS_USR6)       { *p++ = 'G'; }
  if (rights & PRSFS_USR7)       { *p++ = 'H'; }
  *p=0;

  return buff;
}


static int32 parse_rights(buffer,rights)
char *buffer;
int32 *rights;
{
  char *p;

  *rights = 0;

  p=buffer;

  while(*p) {
      switch(*p) {
        case 'r':   *rights |= PRSFS_READ; break;
        case 'w':   *rights |= PRSFS_WRITE; break;
        case 'i':   *rights |= PRSFS_INSERT; break;
        case 'l':   *rights |= PRSFS_LOOKUP; break;
        case 'd':   *rights |= PRSFS_DELETE; break;
        case 'k':   *rights |= PRSFS_LOCK; break;
        case 'a':   *rights |= PRSFS_ADMINISTER; break;
        case 'A':   *rights |= PRSFS_USR0; break;
        case 'B':   *rights |= PRSFS_USR1; break;
        case 'C':   *rights |= PRSFS_USR2; break;
        case 'D':   *rights |= PRSFS_USR3; break;
        case 'E':   *rights |= PRSFS_USR4; break;
        case 'F':   *rights |= PRSFS_USR5; break;
        case 'G':   *rights |= PRSFS_USR6; break;
        case 'H':   *rights |= PRSFS_USR7; break;
        default :   
          return EINVAL;
      }
      p++;
   }
   return 0;
}


static int32 canonical_parse_rights(buffer,rights)
char *buffer;
int32 *rights;
{
  char *p;

  *rights = 0;

  p=buffer;

  if (strcmp(p,"read")==0) p = "rl";
  else if (strcmp(p,"write")==0) p = "rlidwk";
  else if (strcmp(p,"all")==0) p ="rlidwka";
  else if (strcmp(p,"mail")==0) p ="lik";
  else if (strcmp(p,"none")==0) p ="";

  return parse_rights(p,rights);
}

/* return 1 if name is all '-' or digits. Used to remove orphan
     entries from ACls */

static int32
name_is_numeric(name)
char *name;
{

 if (*name != '-' && !isdigit(*name)) return 0;
 else name++;

 while(*name) {
   if (! isdigit(*name)) return 0;
   name++;
 }

 return 1; /* name is (most likely numeric) */
}


static int32 
parse_acl(p, ph, nh)
char *p;
HV *ph, *nh;
{
  int32 pos, neg, acl;
  char *facl;
  char user[MAXSIZE];

  if (sscanf(p,"%d",&pos)!=1) return 0;
  while (*p && *p != '\n') p++;
  if (*p == '\n') p++;
  if (sscanf(p,"%d",&neg)!=1) return 0;
  while (*p && *p != '\n') p++;
  if (*p == '\n') p++;
  while (pos--) {
    if (sscanf(p,"%s %d",user, &acl) !=2) return 0;
    facl = format_rights(acl);
    hv_store(ph,user,strlen(user),newSVpv(facl,strlen(facl)),0);
    while (*p && *p != '\n') p++;              
    if (*p == '\n') p++;
  }
  while (neg--) {
    if (sscanf(p,"%s %d",user, &acl) !=2) return 0;
    facl = format_rights(acl);
    hv_store(nh,user,strlen(user),newSVpv(facl,strlen(facl)),0);
    while (*p && *p != '\n') p++;              
    if (*p == '\n') p++;
  }
  return 1;
}


static
parse_volstat(stats,space)
HV *stats;
char *space;
{
  struct VolumeStatus *status;
  char *name, *offmsg, *motd;
  char type[32];
  status = (VolumeStatus *)space;
  name = (char *)status + sizeof(*status);
  offmsg = name + strlen(name) + 1;
  motd = offmsg + strlen(offmsg) + 1;
  hv_store(stats, "Name",4, newSVpv(name,strlen(name)),0);
  hv_store(stats, "OffMsg",6, newSVpv(offmsg,strlen(offmsg)),0);
  hv_store(stats, "Motd",4, newSVpv(motd,strlen(motd)),0);
  hv_store(stats, "Vid",3, newSViv(status->Vid),0);
  hv_store(stats, "ParentId",8, newSViv(status->ParentId),0);
  hv_store(stats, "Online",6, newSViv(status->Online),0);
  hv_store(stats, "InService",9, newSViv(status->InService),0);
  hv_store(stats, "Blessed",7, newSViv(status->Blessed),0);
  hv_store(stats, "NeedsSalvage",12, newSViv(status->NeedsSalvage),0);
  if (status ->Type == ReadOnly) strcpy(type,"ReadOnly");
  else if (status ->Type == ReadWrite) strcpy(type,"ReadWrite");
  else sprintf(type,"%d",status->Type);
  hv_store(stats, "Type",4, newSVpv(type,strlen(type)),0);
  hv_store(stats, "MinQuota",8, newSViv(status->MinQuota),0);
  hv_store(stats, "MaxQuota",8, newSViv(status->MaxQuota),0);
  hv_store(stats, "BlocksInUse",11, newSViv(status->BlocksInUse),0);
  hv_store(stats, "PartBlocksAvail",15, newSViv(status->PartBlocksAvail),0);
  hv_store(stats, "PartMaxBlocks",13, newSViv(status->PartMaxBlocks),0);
  return 1;

}

static
parse_kaentryinfo(stats,ka)
HV *stats;
struct kaentryinfo *ka;
{
  char buffer[sizeof(struct kaident)];

  sprintf(buffer,"%s%s%s",ka->modification_user.name,
   ka->modification_user.instance[0] ? "." : "",
   ka->modification_user.instance);

  hv_store(stats, "modification_user",17, newSVpv(buffer,strlen(buffer)),0);
  hv_store(stats, "minor_version",13, newSViv(ka->minor_version),0);
  hv_store(stats, "flags",5, newSViv(ka->flags),0);
  hv_store(stats, "user_expiration",15, newSViv(ka->user_expiration),0);
  hv_store(stats, "modification_time",17, newSViv(ka->modification_time),0);
  hv_store(stats, "change_password_time",20, 
                                newSViv(ka->change_password_time),0);
  hv_store(stats, "max_ticket_lifetime",19,newSViv(ka->max_ticket_lifetime),0);
  hv_store(stats, "key_version",11, newSViv(ka->key_version),0);
  hv_store(stats, "keyCheckSum",11, newSViv(ka->keyCheckSum),0);
  hv_store(stats, "misc_auth_bytes",15, newSViv(ka->keyCheckSum),0);
  /*               1234567890123456789012345*/
  return 1;
}

static
parse_ka_getstats(stats,dstats,kas,kad)
HV *stats;
HV *dstats;
struct kasstats *kas;
struct kadstats *kad;
{
  char buff[1024];
  int i;

  hv_store(stats, "minor_version",13, newSViv(kas->minor_version),0);
  hv_store(stats, "allocs",6, newSViv(kas->allocs),0);
  hv_store(stats, "frees",5, newSViv(kas->frees),0);
  hv_store(stats, "cpws",4, newSViv(kas->cpws),0);
  hv_store(stats, "reserved1",9, newSViv(kas->reserved1),0);
  hv_store(stats, "reserved2",9, newSViv(kas->reserved2),0);
  hv_store(stats, "reserved3",9, newSViv(kas->reserved3),0);
  hv_store(stats, "reserved4",9, newSViv(kas->reserved4),0);

  /* dynamic stats */

  hv_store(dstats, "minor_version",13, newSViv(kad->minor_version),0);

  hv_store(dstats, "host",4, newSViv(kad->host),0);
  hv_store(dstats, "start_time",10, newSViv(kad->start_time),0);
  hv_store(dstats, "hashTableUtilization",20, newSViv(kad->hashTableUtilization),0);
  hv_store(dstats, "string_checks",13, newSViv(kad->string_checks),0);
  hv_store(dstats, "reserved1",9, newSViv(kad->reserved1),0);
  hv_store(dstats, "reserved2",9, newSViv(kad->reserved2),0);
  hv_store(dstats, "reserved3",9, newSViv(kad->reserved3),0);
  hv_store(dstats, "reserved4",9, newSViv(kad->reserved4),0);
  hv_store(dstats, "Authenticate_requests",21,
				newSViv(kad->Authenticate.requests),0);
  hv_store(dstats, "Authenticate_aborts",19,
				newSViv(kad->Authenticate.aborts),0);
  hv_store(dstats, "ChangePassword_requests",23,
				newSViv(kad->ChangePassword.requests),0);
  hv_store(dstats, "ChangePassword_aborts",21,
				newSViv(kad->ChangePassword.aborts),0);
  hv_store(dstats, "GetTicket_requests",18,newSViv(kad->GetTicket.requests),0);
  hv_store(dstats, "GetTicket_aborts",16,newSViv(kad->GetTicket.aborts),0);
  hv_store(dstats, "CreateUser_requests",19,
				newSViv(kad->CreateUser.requests),0);
  hv_store(dstats, "CreateUser_aborts",17,newSViv(kad->CreateUser.aborts),0);
  hv_store(dstats, "SetPassword_requests",20,
				newSViv(kad->SetPassword.requests),0);
  hv_store(dstats, "SetPassword_aborts",18,newSViv(kad->SetPassword.aborts),0);
  hv_store(dstats, "SetFields_requests",18,newSViv(kad->SetFields.requests),0);
  hv_store(dstats, "SetFields_aborts",16,newSViv(kad->SetFields.aborts),0);
  hv_store(dstats, "DeleteUser_requests",19,
				newSViv(kad->DeleteUser.requests),0);
  hv_store(dstats, "DeleteUser_aborts",17,newSViv(kad->DeleteUser.aborts),0);
  hv_store(dstats, "GetEntry_requests",17,newSViv(kad->GetEntry.requests),0);
  hv_store(dstats, "GetEntry_aborts",15,newSViv(kad->GetEntry.aborts),0);
  hv_store(dstats, "ListEntry_requests",18,newSViv(kad->ListEntry.requests),0);
  hv_store(dstats, "ListEntry_aborts",16,newSViv(kad->ListEntry.aborts),0);
  hv_store(dstats, "GetStats_requests",17,newSViv(kad->GetStats.requests),0);
  hv_store(dstats, "GetStats_aborts",15,newSViv(kad->GetStats.aborts),0);
  hv_store(dstats, "GetPassword_requests",20,
				newSViv(kad->GetPassword.requests),0);
  hv_store(dstats, "GetPassword_aborts",18,newSViv(kad->GetPassword.aborts),0);
  hv_store(dstats, "GetRandomKey_requests",21,
				newSViv(kad->GetRandomKey.requests),0);
  hv_store(dstats, "GetRandomKey_aborts",19,
				newSViv(kad->GetRandomKey.aborts),0);
  hv_store(dstats, "Debug_requests",14,newSViv(kad->Debug.requests),0);
  hv_store(dstats, "Debug_aborts",12,newSViv(kad->Debug.aborts),0);
  hv_store(dstats, "UAuthenticate_requests",22,
				newSViv(kad->UAuthenticate.requests),0);
  hv_store(dstats, "UAuthenticate_aborts",20,
				newSViv(kad->UAuthenticate.aborts),0);
  hv_store(dstats, "UGetTicket_requests",19,
				newSViv(kad->UGetTicket.requests),0);
  hv_store(dstats, "UGetTicket_aborts",17,newSViv(kad->UGetTicket.aborts),0);
  hv_store(dstats, "Unlock_requests",15,newSViv(kad->Unlock.requests),0);
  hv_store(dstats, "Unlock_aborts",13,newSViv(kad->Unlock.aborts),0);
  hv_store(dstats, "LockStatus_requests",19,
				newSViv(kad->LockStatus.requests),0);
  hv_store(dstats, "LockStatus_aborts",17,newSViv(kad->LockStatus.aborts),0);
   /*               1234567890123456789012345*/


  return 1;
}

static
parse_ka_debugInfo(stats,ka)
HV *stats;
struct ka_debugInfo *ka;
{
  char buff[1024];
  int i;

  hv_store(stats,"lastOperation",13, newSVpv(ka->lastOperation,strlen(ka->lastOperation)),0);

  hv_store(stats,"lastAuth",7, newSVpv(ka->lastAuth,strlen(ka->lastAuth)),0);
  hv_store(stats,"lastUAuth",9, newSVpv(ka->lastUAuth,strlen(ka->lastUAuth)),0);

  hv_store(stats,"lastTGS",7, newSVpv(ka->lastTGS,strlen(ka->lastTGS)),0);
  hv_store(stats,"lastUTGS",8, newSVpv(ka->lastUTGS,strlen(ka->lastUTGS)),0);

  hv_store(stats,"lastAdmin",9, newSVpv(ka->lastAdmin,strlen(ka->lastAdmin)),0);
  hv_store(stats,"lastTGSServer",13, newSVpv(ka->lastTGSServer,strlen(ka->lastTGSServer)),0);
  hv_store(stats,"lastUTGSServer",14, newSVpv(ka->lastUTGSServer,strlen(ka->lastUTGSServer)),0);

  hv_store(stats, "minorVersion",12, newSViv(ka->minorVersion),0);
  hv_store(stats, "host",4, newSViv(ka->host),0);
  hv_store(stats, "startTime",9, newSViv(ka->startTime),0);
  hv_store(stats, "noAuth",6, newSViv(ka->noAuth),0);
  hv_store(stats, "lastTrans",9, newSViv(ka->lastTrans),0);
  hv_store(stats, "nextAutoCPW",11, newSViv(ka->nextAutoCPW),0);
  hv_store(stats, "updatesRemaining",16, newSViv(ka->updatesRemaining),0);
  hv_store(stats, "dbHeaderRead",12, newSViv(ka->dbHeaderRead),0);

  hv_store(stats, "dbVersion",9, newSViv(ka->dbVersion),0);
  hv_store(stats, "dbFreePtr",9, newSViv(ka->dbFreePtr),0);
  hv_store(stats, "dbEofPtr",8, newSViv(ka->dbEofPtr),0);
  hv_store(stats, "dbKvnoPtr",9, newSViv(ka->dbKvnoPtr),0);

  hv_store(stats, "dbSpecialKeysVersion",20, newSViv(ka->dbSpecialKeysVersion),0);

  hv_store(stats, "cheader_lock",12, newSViv(ka->cheader_lock),0);
  hv_store(stats, "keycache_lock",13, newSViv(ka->keycache_lock),0);
  hv_store(stats, "kcVersion",9, newSViv(ka->kcVersion),0);
  hv_store(stats, "kcSize",6, newSViv(ka->kcSize),0);

  hv_store(stats, "reserved1",9, newSViv(ka->reserved1),0);
  hv_store(stats, "reserved2",9, newSViv(ka->reserved2),0);
  hv_store(stats, "reserved3",9, newSViv(ka->reserved3),0);
  hv_store(stats, "reserved4",9, newSViv(ka->reserved4),0);

  if (ka->kcUsed > KADEBUGKCINFOSIZE) {
    hv_store(stats, "actual_kcUsed",13, newSViv(ka->kcUsed),0);
    ka->kcUsed = KADEBUGKCINFOSIZE;
  }

  hv_store(stats, "kcUsed",6, newSViv(ka->kcUsed),0);

  for (i=0; i < ka->kcUsed; i++) {
    sprintf(buff,"kcInfo_used%d",i);
    hv_store(stats, buff,strlen(buff), newSViv(ka->kcInfo[i].used),0);

    sprintf(buff,"kcInfo_kvno%d",i);
    hv_store(stats, buff,strlen(buff), newSViv(ka->kcInfo[i].kvno),0);

    sprintf(buff,"kcInfo_primary%d",i);
    hv_store(stats, buff,strlen(buff), 
                    newSViv((unsigned char)ka->kcInfo[i].primary),0);

    sprintf(buff,"kcInfo_keycksum%d",i);
    hv_store(stats, buff,strlen(buff), 
                    newSViv((unsigned char) ka->kcInfo[i].keycksum),0);

    sprintf(buff,"kcInfo_principal%d",i);
    hv_store(stats, buff, strlen(buff),
         newSVpv(ka->kcInfo[i].principal,strlen(ka->kcInfo[i].principal)),0);
  }


  /*               1234567890123456789012345*/


  return 1;
}

static int32
parse_pts_setfields(access,flags)
char *access;
int32 *flags;
{
  *flags = 0;
  if (strlen(access) != 5) return PRBADARG;

  if (access[0] == 'S') *flags |= 0x80;
  else if (access[0] == 's') *flags |= 0x40;
  else if (access[0] != '-') return PRBADARG;

  if (access[1] == 'O') *flags |= 0x20;
  else if (access[1] != '-') return PRBADARG;

  if (access[2] == 'M') *flags |= 0x10;
  else if (access[2] == 'm') *flags |= 0x08;
  else if (access[2] != '-') return PRBADARG;

  if (access[3] == 'A') *flags |= 0x04;
  else if (access[3] == 'a') *flags |= 0x02;
  else if (access[3] != '-') return PRBADARG;

  if (access[4] == 'r') *flags |= 0x01;
  else if (access[4] != '-') return PRBADARG;

  return 0;

}

static char *
parse_flags_ptsaccess(flags)
int32 flags;
{
      static char buff[6];
      strcpy(buff,"-----");
      if (flags & 0x01) buff[4] = 'r';
      if (flags & 0x02) buff[3] = 'a';
      if (flags & 0x04) buff[3] = 'A';
      if (flags & 0x08) buff[2] = 'm';
      if (flags & 0x10) buff[2] = 'M';
      if (flags & 0x20) buff[1] = 'O';
      if (flags & 0x40) buff[0] = 's';
      if (flags & 0x80) buff[0] = 'S';
      return buff;
}

static
parse_prcheckentry(server,stats,entry,lookupids,convertflags)
struct ubik_client *server;
HV *stats;
struct prcheckentry *entry;
int32 lookupids;
{
  int32 code;
  char name[PR_MAXNAMELEN];

  hv_store(stats, "id",2, newSViv(entry->id),0);
  hv_store(stats, "name",4, newSVpv(entry->name,strlen(entry->name)),0);
  if (convertflags) {
      hv_store(stats, "flags",5, 
           newSVpv(parse_flags_ptsaccess(entry->flags),5),0);
  } else {
     hv_store(stats, "flags",5, newSViv(entry->flags),0);
  }
  if (lookupids) {
     code = internal_pr_name(server,entry->owner,name);
     if (code) hv_store(stats, "owner",5, newSViv(entry->owner),0);
     else hv_store(stats, "owner",5, newSVpv(name,strlen(name)),0);
     code = internal_pr_name(server,entry->creator,name);
     if (code) hv_store(stats, "creator",7, newSViv(entry->creator),0);
     else hv_store(stats, "creator",7, newSVpv(name,strlen(name)),0);
  } else {
     hv_store(stats, "owner",5, newSViv(entry->owner),0);
     hv_store(stats, "creator",7, newSViv(entry->creator),0);
   }
  hv_store(stats, "ngroups",7, newSViv(entry->ngroups),0);
/*  hv_store(stats, "nusers",6, newSViv(entry->nusers),0);*/
  hv_store(stats, "count",5, newSViv(entry->count),0);
/*
  hv_store(stats, "reserved0",9, newSViv(entry->reserved[0]),0);
  hv_store(stats, "reserved1",9, newSViv(entry->reserved[1]),0);
  hv_store(stats, "reserved2",9, newSViv(entry->reserved[2]),0);
  hv_store(stats, "reserved3",9, newSViv(entry->reserved[3]),0);
  hv_store(stats, "reserved4",9, newSViv(entry->reserved[4]),0);
*/

  return 1;

}


static
parse_prdebugentry(server,stats,entry,lookupids,convertflags)
struct ubik_client *server;
HV *stats;
struct prdebugentry *entry;
int32 lookupids;
{
  int32 code;
  char name[PR_MAXNAMELEN];
  char buff[128];
  int i;

  hv_store(stats, "id",2, newSViv(entry->id),0);
  hv_store(stats, "name",4, newSVpv(entry->name,strlen(entry->name)),0);

  if (convertflags) {
      hv_store(stats, "flags",5, 
           newSVpv(parse_flags_ptsaccess(entry->flags),5),0);
  } else {
     hv_store(stats, "flags",5, newSViv(entry->flags),0);
  }

  if (lookupids) {
     code = internal_pr_name(server,entry->owner,name);
     if (code) hv_store(stats, "owner",5, newSViv(entry->owner),0);
     else hv_store(stats, "owner",5, newSVpv(name,strlen(name)),0);

     code = internal_pr_name(server,entry->creator,name);
     if (code) hv_store(stats, "creator",7, newSViv(entry->creator),0);
     else hv_store(stats, "creator",7, newSVpv(name,strlen(name)),0);

     for (i=0; i<10; i++) {
        sprintf(buff,"entries%d",i);
     code = internal_pr_name(server,entry->entries[i],name);
     if (code) hv_store(stats, buff,strlen(buff), newSViv(entry->entries[i]),0);
     else hv_store(stats,buff,strlen(buff),newSVpv(name,strlen(name)),0);

     }
      
  } else {
     hv_store(stats, "owner",5, newSViv(entry->owner),0);
     hv_store(stats, "creator",7, newSViv(entry->creator),0);
     for (i=0; i<10; i++) {
        sprintf(buff,"entries%d",i);
       hv_store(stats, buff,strlen(buff), newSViv(entry->entries[i]),0);
     }

   }
  hv_store(stats, "cellid",6, newSViv(entry->cellid),0);
  hv_store(stats, "next",4, newSViv(entry->next),0);
  hv_store(stats, "nextID",6, newSViv(entry->nextID),0);
  hv_store(stats, "nextname",8, newSViv(entry->nextname),0);
  hv_store(stats, "ngroups",7, newSViv(entry->ngroups),0);
  hv_store(stats, "nusers",6, newSViv(entry->nusers),0);
  hv_store(stats, "count",5, newSViv(entry->count),0);
  hv_store(stats, "instance",8, newSViv(entry->instance),0);
  hv_store(stats, "owned",5, newSViv(entry->owned),0);
  hv_store(stats, "nextOwned",9, newSViv(entry->nextOwned),0);
  hv_store(stats, "parent",6, newSViv(entry->parent),0);
  hv_store(stats, "sibling",7, newSViv(entry->sibling),0);
  hv_store(stats, "child",5, newSViv(entry->child),0);
  hv_store(stats, "reserved0",9, newSViv(entry->reserved[0]),0);
  hv_store(stats, "reserved1",9, newSViv(entry->reserved[1]),0);
  hv_store(stats, "reserved2",9, newSViv(entry->reserved[2]),0);
  hv_store(stats, "reserved3",9, newSViv(entry->reserved[3]),0);
  hv_store(stats, "reserved4",9, newSViv(entry->reserved[4]),0);

  return 1;

}

static int32 check_name_for_id(name,id)
char *name;
int32 id;
{
  char buff[32];
  sprintf(buff,"%d",id);
  return strcmp(buff,name)==0;
}

/************************ Start of XS stuff **************************/
/* PROTOTYPES: DISABLE added by leg@andrew, 10/7/96 */

MODULE = AFS	PACKAGE = AFS	PREFIX = fs_
PROTOTYPES: DISABLE

void
fs_pioctl(path,setpath,op,in,setin,setout,follow)
	char *	path
	int32	setpath
	int32	op
	SV *	in
	int32	setin
	int32	setout
	int32	follow
   PPCODE:
   {
	struct  ViceIoctl vi;
	int32 code;
	char space[MAXSIZE];
        STRLEN insize;

	if (!setpath) path = NULL;
        if (setout) {
           space[0] = '\0';
           vi.out_size = MAXSIZE;
           vi.out = space;
        } else {          
	   vi.out_size = 0;
           vi.out = 0;
        }
	if (setin) {
           vi.in = (char*) SvPV(ST(2),insize);
           vi.in_size = insize;
        } else {
           vi.in = 0;
           vi.in_size = 0;
        }
        code = pioctl(path, op, &vi, follow);
        FSSETCODE(code);
        if (code==0 && setout) {
             EXTEND(sp,1);
             printf("out_size = %d\n", vi.out_size);
             PUSHs(sv_2mortal(newSVpv(vi.out,vi.out_size)));
	}
   }


void
fs_getvolstats(dir,follow=1)
	char *	dir
	int32	follow
   PPCODE:
   {
	struct  ViceIoctl vi;
	int32 code;
	char space[MAXSIZE];
        HV *stats;

        vi.out_size = MAXSIZE;
        vi.in_size = 0;
        vi.out = space;
        code = pioctl(dir, VIOCGETVOLSTAT, &vi, follow);
        FSSETCODE(code);
        if (code==0) {
           stats = newHV();
           if (parse_volstat(stats,space)) {
                  EXTEND(sp,1);
                  PUSHs(sv_2mortal(newRV_inc((SV*)stats)));
           } else {
		hv_undef(stats);
           }
	}
   }

void
fs_whereis(dir,ip=0,follow=1)
	char *	dir
	int32	ip
	int32	follow
   PPCODE:
   {
	struct  ViceIoctl vi;
	int32 code;
	char space[MAXSIZE];

        vi.out_size = MAXSIZE;
        vi.in_size = 0;
        vi.out = space;
        code = pioctl(dir, VIOCWHEREIS, &vi, follow);
        FSSETCODE(code);
        if (code==0) {
	     struct in_addr *hosts = (struct in_addr *) space;
	     struct hostent *ht;
             int i;
             char *h;
             for (i=0; i<MAXHOSTS; i++) {
                if (hosts[i].s_addr == 0) break;
                if (ip==0) {
                 ht = gethostbyaddr((const char *)&hosts[i], sizeof(struct in_addr),AF_INET);
                 if (ht==NULL) h = (char*)inet_ntoa(hosts[i]);
                 else h =  ht->h_name;
                } else {
                    h = (char*)inet_ntoa(hosts[i]);
                }
                XPUSHs(sv_2mortal(newSVpv(h,strlen(h))));
             }

	}
   }



void
fs_checkservers(fast,cell=0,ip=0)
	int32	fast
	char *	cell
	int32	ip
   PPCODE:
   {
        struct chservinfo checkserv;
	struct  ViceIoctl vi;
	int32 code, *num;
	char space[MAXSIZE];

        checkserv.magic = 0x12345678;
	checkserv.tflags = 2;
        if (fast) checkserv.tflags |= 0x1;
        if (cell) {
            checkserv.tflags &= ~2;
            strcpy(checkserv.tbuffer,cell);
	    checkserv.tsize = strlen(cell);
        }
        checkserv.tinterval =  -1;
 
        vi.out_size = MAXSIZE;
        vi.in_size = sizeof(checkserv);
	vi.in = (char*)&checkserv;
        vi.out = space;
        
        code = pioctl(0, VIOCCKSERV, &vi, 1);
        num = (int32 *) space;
        FSSETCODE(code);
        if (code==0 && *num>0) {
	     struct in_addr *hosts = (struct in_addr *) (space+sizeof(int32));
	     struct hostent *ht;
             int i;
             char *h;
             for (i=0; i<MAXHOSTS; i++) {
                if (hosts[i].s_addr == 0) break;
                if (ip==0) {
                 ht = gethostbyaddr((const char *)&hosts[i], sizeof(struct in_addr),AF_INET);
                 if (ht==NULL) h = (char*)inet_ntoa(hosts[i]);
                 else h =  ht->h_name;
                } else {
                    h = (char*)inet_ntoa(hosts[i]);
                }
                XPUSHs(sv_2mortal(newSVpv(h,strlen(h))));
             }

	}
   }


void
fs_getcell(in_index,ip=0)
	int32	in_index
	int32	ip
   PPCODE:
   {
	struct  ViceIoctl vi;
	int32 code,max=OMAXHOSTS;
        int32 *lp;
	char space[MAXSIZE];

        lp = (int32 *)space;
        *lp++ = in_index;
        *lp = 0x12345678;  
        vi.in_size = sizeof(int32)*2;
        vi.in = (char*) space;
        vi.out_size = MAXSIZE;
        vi.out = space;
        code = pioctl(NULL, VIOCGETCELL, &vi, 1);
        FSSETCODE(code);
        if (code==0) {
	     struct in_addr *hosts = (struct in_addr *) space;
             int32 *magic = (int32 *) space;
	     struct hostent *ht;
             int i;
             char *h;
        /*if (*magic == 0x12345678) {*/
                 max = MAXHOSTS;
        /*            hosts++; */
        /*    }*/
             h =(char*) hosts+max*sizeof(int32);
             XPUSHs(sv_2mortal(newSVpv(h,strlen(h))));          
             for (i=0; i<max; i++) {
                if (hosts[i].s_addr == 0) break;
                if (ip==0) {
                 ht = gethostbyaddr((const char *)&hosts[i], sizeof(struct in_addr),AF_INET);
                 if (ht==NULL) h = (char*)inet_ntoa(hosts[i]);
                 else h =  ht->h_name;
                } else {
                    h = (char*)inet_ntoa(hosts[i]);
                }
                XPUSHs(sv_2mortal(newSVpv(h,strlen(h))));
             }

	}
   }


void
fs__get_server_version(port,hostName="localhost",verbose=0)
short port
char *hostName
int32 verbose
  CODE:
  {
#if defined(AFS_3_4)
  not_here("_get_server_version");
#else
  struct sockaddr_in taddr;
  struct in_addr hostAddr;
  struct hostent *th;
  int32 host;
  short port_num = htons(port);
  int32 length = 64;
  int32 code;
  char version[64];
  int s;
  char a[1] = {0};

  /* lookup host */
  if (hostName) {
      th = (struct hostent *)hostutil_GetHostByName(hostName);
      if (!th) {
          warn("rxdebug: host %s not found in host table\n", hostName);
          FSSETCODE(EFAULT);
          XSRETURN_UNDEF;
      }
      bcopy(th->h_addr, &host, sizeof(int32));
  }
  else host = htonl(0x7f000001);      /* IP localhost */

  hostAddr.s_addr = host;
  if (verbose) printf("Trying %s (port %d):\n", inet_ntoa(hostAddr), ntohs(port_num));

  s = socket(AF_INET, SOCK_DGRAM, 0);
  taddr.sin_family = AF_INET;
  taddr.sin_port = 0;
  taddr.sin_addr.s_addr = 0;

  code = bind(s, (struct sockaddr *) &taddr, sizeof(struct sockaddr_in));
  FSSETCODE(code);
  if (code) {
      perror("bind");
      XSRETURN_UNDEF;
  }

  code = rx_GetServerVersion(s, host, port_num, length, version);
  ST(0) = sv_newmortal();
  if (code < 0) {
      FSSETCODE(code);
  }
  else {
      sv_setpv(ST(0), version);
  }
#endif
 }


void
fs_get_syslib_version()
  CODE:
  {
  extern char *AFSVersion;

  ST(0) = sv_newmortal();
  sv_setpv(ST(0), AFSVersion);
 }


void
fs_XSVERSION()
  CODE:
  {

  ST(0) = sv_newmortal();
  sv_setpv(ST(0), xs_version);
 }


void
fs_sysname(newname=0)
char *	newname
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code,set;
  char space[MAXSIZE];

  set = (newname && *newname);

  vi.in = space;
  bcopy(&set,space,sizeof(set));
  vi.in_size = sizeof(set);
  if (set) {
     strcpy(space+sizeof(set),newname);
     vi.in_size += strlen(newname)+1;
  }
  vi.out_size = MAXSIZE;
  vi.out = (caddr_t) space;
  code = pioctl(NULL, VIOC_AFS_SYSNAME, &vi, 0);
  FSSETCODE(code);  
  ST(0) = sv_newmortal();
  if (code==0) {
      sv_setpv(ST(0), space+sizeof(set));
  }
 }


void
fs_getcrypt()
  CODE:
  {
#ifdef VIOC_GETRXKCRYPT
  struct  ViceIoctl vi;
  int32 code, flag;
  char space[MAXSIZE];

  vi.in_size = 0;
  vi.out_size = MAXSIZE;
  vi.out = (caddr_t) space;
  code = pioctl(0, VIOC_GETRXKCRYPT, &vi, 1);
  FSSETCODE(code);

  ST(0) = sv_newmortal();
  if (code==0) {
      bcopy((char *)space, &flag, sizeof(int32));
      sv_setiv(ST(0), flag);
  }
#else
  not_here("getcrypt");
#endif
 }


int32
fs_setcrypt(as)
char *as
  CODE:
  {
#ifdef VIOC_SETRXKCRYPT
  struct  ViceIoctl vi;
  int32 code, flag;
  char space[MAXSIZE];

  if (strcmp(as, "on") == 0)
    flag = 1;
  else if (strcmp(as, "off") == 0)
    flag = 0;
  else {
    warn ("setcrypt: %s must be \"on\" or \"off\".\n", as);
    FSSETCODE(EINVAL);
    XSRETURN_UNDEF;
  }

  vi.in = (char *) &flag;
  vi.in_size = sizeof(flag);
  vi.out_size = 0;
  code = pioctl(0, VIOC_SETRXKCRYPT, &vi, 1);
  FSSETCODE(code);
  RETVAL = (code==0);
#else
  not_here("setcrypt");
#endif
 }
 OUTPUT:
        RETVAL


void
fs_whichcell(dir,follow=1)
char *  dir
int32   follow
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  char space[MAXSIZE];

  vi.in_size = 0;
  vi.out_size = MAXSIZE;
  vi.out = (caddr_t) space;
  code = pioctl(dir, VIOC_FILE_CELL_NAME, &vi, follow);
  FSSETCODE(code);  
  ST(0) = sv_newmortal();
  if (code==0) {
      sv_setpv(ST(0), space);
  }
 }

void
fs_lsmount(path,follow=1)
char *  path
int32   follow
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  char space[MAXSIZE];
  char *dir,*file;
  char parent[1024];

  if (strlen(path) > (sizeof(parent)-1)) code = EINVAL;
  else {
    strcpy(parent,path);
    file = strrchr(parent, '/');
    if (file) {
      dir = parent;
      *file++ = '\0';
    } else {
      dir = ".";
      file = parent;
    }

    vi.in_size = strlen(file)+1;
    vi.in = file;
    vi.out_size = MAXSIZE;
    vi.out = (caddr_t) space;
    code = pioctl(dir, VIOC_AFS_STAT_MT_PT, &vi, follow);
  }
  FSSETCODE(code);  
  ST(0) = sv_newmortal();
  if (code==0) {
      sv_setpv(ST(0), space);
  }
 }


int32
fs_rmmount(path)
char *  path
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  char *file, *dir;
  char parent[1024];

  if (strlen(path) > (sizeof(parent)-1)) code = EINVAL;
  else {
    strcpy(parent,path);
    file = strrchr(parent, '/');
    if (file) {
      dir = parent;
      *file++ = '\0';
    } else {
      dir = ".";
      file = parent;
    }

    vi.in_size = strlen(file)+1;
    vi.in = file;
    vi.out_size = 0;
    code = pioctl(dir, VIOC_AFS_DELETE_MT_PT, &vi, 0);
  }
  FSSETCODE(code);  
  RETVAL = (code==0);
 }
 OUTPUT:
        RETVAL

int32
fs_flushvolume(path,follow=1)
char *  path
int32   follow
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  char space[MAXSIZE];

  vi.in_size = 0;
  vi.out_size = MAXSIZE;
  vi.out = (caddr_t) space;
  code = pioctl(path, VIOC_FLUSHVOLUME, &vi, follow);
  FSSETCODE(code);  
  RETVAL =  (code==0);
  }
  OUTPUT:
        RETVAL


int32
fs_flush(path,follow=1)
char *  path
int32   follow
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  char space[MAXSIZE];

  vi.in_size = 0;
  vi.out_size = MAXSIZE;
  vi.out = (caddr_t) space;
  code = pioctl(path, VIOCFLUSH, &vi, follow);

  FSSETCODE(code);  
  RETVAL =  (code==0);
  }
  OUTPUT:
        RETVAL


int32
fs_flushcb(path,follow=1)
char *  path
int32   follow
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  char space[MAXSIZE];

  vi.in_size = 0;
  vi.out_size = MAXSIZE;
  vi.out = (caddr_t) space;
  code = pioctl(path, VIOCFLUSHCB, &vi, follow);
  FSSETCODE(code);  
  RETVAL =  (code==0);
  }
  OUTPUT:
        RETVAL

int32
fs_setquota(path,newquota,follow=1)
char *  path
int32   newquota
int32   follow
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  char space[MAXSIZE];
  struct VolumeStatus *status;
# tpf nog 04/09/99  
  char *input;

  vi.in_size = sizeof(*status)+3;
  vi.in = space;
# tpf nog 04/07/99 
# vi.out_size = 0; 
# vi.out = 0;
  vi.out_size = MAXSIZE;
  vi.out = space;
  status = (VolumeStatus *) space;
  status -> MinQuota = -1;
  status -> MaxQuota = newquota;

# tpf nog 04/09/99  from ".../venus/fs.c"
  input = (char *)status + sizeof(*status);
  *(input++) = '\0';      /* never set name: this call doesn't change vldb */
  *(input++) = '\0';      /* offmsg  */
  *(input++) = '\0';      /* motd  */
# tpf nog 04/09/99

  code = pioctl(path, VIOCSETVOLSTAT, &vi, follow);
  FSSETCODE(code);  
  RETVAL =  (code==0);
  }
  OUTPUT:
        RETVAL

void
fs_getquota(path,follow=1)
char *  path
int32   follow
  PPCODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  struct VolumeStatus status;

    vi.in_size = 0;
    vi.in = 0;
    vi.out_size = sizeof(status);
    vi.out = (char*)&status;
    code = pioctl(path, VIOCGETVOLSTAT, &vi, follow);
    FSSETCODE(code);  
    if (code==0) {
      EXTEND(sp,1);
      PUSHs(sv_2mortal(newSViv( status.MaxQuota)));
    }
  }

int32
fs_mkmount(mountp,volume,rw=0,cell=0)
char *	mountp
char *	volume
int32	rw
char *	cell
  CODE:
  {
   char buffer[1024];
   char parent[1024];
   int32 code=0;

   if (cell && !*cell) cell = NULL;

   if (strlen(mountp) > (sizeof(parent)-1)) code = EINVAL;
   else {
       char *p;
       strcpy(parent,mountp);
       p = strrchr(parent, '/');
       if (p) *p = 0; else strcpy(parent,".");
       if (!isafs(parent)) code = EINVAL;
   }

   if (code == 0) {
       sprintf(buffer,"%c%s%s%s.", 
             rw ? '%' : '#', 
             cell ? cell : "",
             cell ? ":"  : "",
             volume);
       code = symlink(buffer,mountp);
   }
   FSSETCODE(code);
   RETVAL =  (code==0);
  }
  OUTPUT:
	RETVAL

int32
fs_checkvolumes()
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;

  vi.in_size = 0;
  vi.out_size = 0;
  code = pioctl(NULL, VIOCCKBACK, &vi, 0);
  FSSETCODE(code);  
  RETVAL =  (code==0);
  }
  OUTPUT:
	RETVAL


int32
fs_checkconn()
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  int32 status;
 
  vi.in_size = 0;
  vi.out_size = sizeof(status);
  vi.out = (caddr_t) &status;
  code = pioctl(NULL, VIOCCKCONN, &vi, 0);
  FSSETCODE(code);  
  RETVAL =  (status==0);
  }
  OUTPUT:
	RETVAL

int32
fs_getcacheparms()
  PPCODE:
  {
    struct  ViceIoctl vi;
    int32 code;
    struct VenusFid vf;
    int32 stats[16];

    vi.in_size = 0;
    vi.in = 0;
    vi.out_size = sizeof(stats);
    vi.out = (char *) stats;
    code = pioctl(NULL, VIOCGETCACHEPARMS, &vi, 0);

    FSSETCODE(code);  
    if (code==0) {
      EXTEND(sp,2);
      PUSHs(sv_2mortal(newSViv(stats[0])));
      PUSHs(sv_2mortal(newSViv(stats[1])));
    }
  }


int32
fs_setcachesize(size)
int32	size
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  int32 status;
 
  vi.in_size = sizeof(size);;
  vi.in = (char*) &size;
  vi.out_size = 0;
  vi.out = 0;
  code = pioctl(NULL, VIOCSETCACHESIZE, &vi, 0);
  FSSETCODE(code);  
  RETVAL =  (code==0);
  }
  OUTPUT:
	RETVAL


int32
fs_unlog()
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
 
  vi.in_size = 0;
  vi.out_size = 0;
  code = pioctl(NULL, VIOCUNLOG, &vi, 0);
  FSSETCODE(code);  
  RETVAL =  (code==0);
  }
  OUTPUT:
	RETVAL


int32
fs_getfid(path,follow=1)
char *	path
int32	follow
  PPCODE:
  {
    struct  ViceIoctl vi;
    int32 code;
    struct VenusFid vf;

    vi.in_size = 0;
    vi.out_size = sizeof(vf);
    vi.out = (char *) &vf;
    code = pioctl(path, VIOCGETFID, &vi, follow);
    FSSETCODE(code);  
    if (code==0) {
      EXTEND(sp,4);
      PUSHs(sv_2mortal(newSViv(vf.Cell)));
      PUSHs(sv_2mortal(newSViv(vf.Fid.Volume)));
      PUSHs(sv_2mortal(newSViv(vf.Fid.Vnode)));
      PUSHs(sv_2mortal(newSViv(vf.Fid.Unique)));
    }
  }


int32
fs_isafs(path,follow=1)
char *	path
int32	follow
   CODE:
   {
	int32 code;
        RETVAL = isafs(path,follow);
	if (!RETVAL) code = errno;
        else code =0;
	FSSETCODE(code);
    }
  OUTPUT:
	RETVAL


int32
# tpf nog 04/19/99  
#fs_access(path,perm="read",follow=1)
fs_cm_access(path,perm="read",follow=1)
char *	path
char *	perm
int32	follow
   CODE:
   {
        struct  ViceIoctl vi;
	int32 code;
	int32 rights;

        code = canonical_parse_rights(perm,&rights);
        if (code==0) {
           code = 
           vi.in_size = sizeof(rights);
           vi.in = (char*) &rights;
           vi.out_size = 0;
           vi.out = 0;
           code = pioctl(path, VIOCACCESS, &vi, follow);
        }         
	FSSETCODE(code);
	RETVAL = ( code == 0);
    }
  OUTPUT:
	RETVAL

int32
fs_ascii2rights(perm)
char *	perm
   CODE:
   {
	int32 code, rights = -1;

        code = canonical_parse_rights(perm,&rights);
	FSSETCODE(code);

        if (code !=0) rights = -1;
	RETVAL = rights;
    }
  OUTPUT:
	RETVAL


void
fs_rights2ascii(perm)
int32	perm
   CODE:
   {
	char buffer[64];
	int32 code;
        char *p;
        p = format_rights(perm);

	FSSETCODE(0);

	ST(0) = sv_newmortal();
	sv_setpv(ST(0), p);
    }

void
fs_crights(perm)
	char *	perm
   CODE:
   {
	int32 code;
        int32 rights;

        char *p;

        code = canonical_parse_rights(perm,&rights);
	SETCODE(code);
        ST(0) = sv_newmortal();
        if (code==0) {
             sv_setpv(ST(0), format_rights(rights));
        }
    }

void
fs_getcellstatus(cell=0)
char *	cell
  PPCODE:
  {
    struct  ViceIoctl vi;
    struct afsconf_cell info;
    int32 code,flags;

   if (cell && !*cell) cell = NULL;
   code = internal_GetCellInfo(cell,0,&info);
   if (code==0) {
      vi.in_size = strlen(info.name)+1;
      vi.in = info.name;
      vi.out_size = sizeof(flags);
      vi.out = (char *) &flags;
      code = pioctl(0, VIOC_GETCELLSTATUS, &vi, 0);
    }
    FSSETCODE(code);  
    if (code==0) {
      EXTEND(sp,1);
      PUSHs(sv_2mortal(newSViv( (flags & 0x2) == 0)));
    }
  }

int32
fs_setcellstatus(setuid_allowed,cell=0)
int32	setuid_allowed
char *	cell
  PPCODE:
  {
    struct  ViceIoctl vi;
    struct afsconf_cell info;
    int32 code;
    struct set_status {
        int32 status;
        int32 reserved;
        char cell[MAXCELLCHARS];
    } set;

   if (cell && !*cell) cell = NULL;
   code = internal_GetCellInfo(cell,0,&info);
   if (code==0) {
      set.reserved=0;
      strcpy(set.cell,info.name);
      if (setuid_allowed) set.status = 0;
      else set.status = 0x2;
      vi.in_size = sizeof(set);
      vi.in = (char*) &set;
      vi.out_size = 0;
      vi.out = (char *) 0;
      code = pioctl(0, VIOC_SETCELLSTATUS, &vi, 0);
    }
    FSSETCODE(code);  
    EXTEND(sp,1);
    PUSHs(sv_2mortal(newSViv(code==0)));
  }

void
fs_wscell()
  CODE:
  {
  struct  ViceIoctl vi;
  int32 code;
  char space[MAXSIZE];

  vi.in_size = 0;
  vi.out_size = MAXSIZE;
  vi.out = (caddr_t) space;
  code = pioctl(NULL, VIOC_GET_WS_CELL, &vi, 0);
  FSSETCODE(code);  
  ST(0) = sv_newmortal();
  if (code==0) {
      sv_setpv(ST(0), space);
  }
 }


void
fs_getacl(dir,follow=1)
	char *	dir
	int32	follow
   PPCODE:
  {
	struct  ViceIoctl vi;
	int32 code;
	char space[MAXSIZE];
        HV *ph, *nh;
        vi.out_size = MAXSIZE;
        vi.in_size = 0;
        vi.out = space;
        code = pioctl(dir, VIOCGETAL, &vi, follow);
	FSSETCODE(code);

        if (code==0) {
            ph = newHV();
            nh = newHV();

           if (parse_acl(space, ph, nh)) {
               AV *acl;
               acl = newAV();
               av_store(acl,0, newRV_inc((SV*)ph));
               av_store(acl,1, newRV_inc((SV*)nh));	
               EXTEND(sp, 1);
               PUSHs(sv_bless(sv_2mortal(newRV_inc((SV*)acl)),
                                          gv_stashpv("AFS::ACL",1)));
	   } else {
               hv_undef(ph);
               hv_undef(nh);
          }
        }
   }

int32
fs_setacl(dir,acl,follow=1)
	char *	dir
	SV *	acl
	int32	follow
   CODE:
  {
	struct  ViceIoctl vi;
	int32 code;
	char space[MAXSIZE];
	char acls[MAXSIZE], *p;
        HV *ph, *nh;
        AV *object;
        SV **sv;
        HE *he;
        int plen, nlen;
        int32 rights;
        char *name, *perm;

        if (   sv_isa(acl,"AFS::ACL") && SvROK(acl)
           && (SvTYPE(SvRV(acl))==SVt_PVAV)
          ) {
             object = (AV*)SvRV(acl);
        } else {
           croak("acl is not of type AFS::ACL");
        }

        ph = nh = NULL;
        sv = av_fetch(object, 0, 0); 

        if (sv) {
           SV *sph = *sv;
           if (SvROK(sph) && (SvTYPE(SvRV(sph)) == SVt_PVHV)) {
              ph = (HV*)SvRV(sph); 
           }
        }

        sv = av_fetch(object, 1, 0); 

        if (sv) {
           SV *snh = *sv;
           if (SvROK(snh) && (SvTYPE(SvRV(snh)) == SVt_PVHV)) {
              nh = (HV*)SvRV(snh); 
           }
        }

        plen = nlen = 0;

        p = acls;
        *p = 0;
        code = 0;

        if (ph) {
           hv_iterinit(ph);
   
           while((code == 0) && (he = hv_iternext(ph))) {
              I32 len;
              name = hv_iterkey(he, &len);
              perm =  SvPV(hv_iterval(ph, he),PL_na);
              code = canonical_parse_rights(perm, &rights);
              if (code==0 && rights && !name_is_numeric(name)) {
                sprintf(p,"%s\t%d\n", name, rights);
                p += strlen(p);
                plen++;
              }
           }
        }
        
        if (code==0 && nh) {
            hv_iterinit(nh);
            while((code==0) && (he = hv_iternext(nh))){
               I32 len;
               name = hv_iterkey(he, &len);
               perm =  SvPV(hv_iterval(nh, he),PL_na);
               code = canonical_parse_rights(perm, &rights);
               if (code==0 && rights && !name_is_numeric(name)) {
                 sprintf(p,"%s\t%d\n", name, rights);
                 p += strlen(p);
                 nlen++;
               }
            }
        }

        if (code ==0) {
           sprintf(space,"%d\n%d\n%s",plen, nlen, acls);
           vi.in_size = strlen(space)+1;
           vi.in      = space;
           vi.out_size = 0;
           vi.out = 0;
           code = pioctl(dir, VIOCSETAL, &vi, follow);
          }
	FSSETCODE(code);
        RETVAL = (code==0);
     }
  OUTPUT:
	RETVAL


MODULE = AFS		PACKAGE = AFS::KTC_PRINCIPAL	PREFIX = ktcp_

AFS::KTC_PRINCIPAL
ktcp__new(class,name,...)
	char *	class
	char *	name
 PPCODE:
 {
  struct ktc_principal *p;
  int32 code;

  if (items != 2 && items !=4) 
          croak("Usage: AFS::KTC_PRINCIPAL->new(USER.INST@CELL) or AFS::KTC_PRINCIPAL->new(USER, INST, CELL)");

  p = (struct ktc_principal *) safemalloc(sizeof(struct ktc_principal));
  p->name[0] = '\0';
  p->instance[0] = '\0';
  p->cell[0] = '\0';

  if (items==2) {
    code = ka_ParseLoginName(name,p->name,p->instance,p->cell);
   } else {
    STRLEN nlen, ilen, clen;
    char *i = (char *)SvPV(ST(2),ilen);
    char *c = (char *)SvPV(ST(3),clen);
    nlen = strlen(name);
    if (  nlen > MAXKTCNAMELEN-1
       || ilen > MAXKTCNAMELEN-1 
       || clen >MAXKTCREALMLEN-1) code = KABADNAME;
    else {
      strcpy(p->name,name);
      strcpy(p->instance,i);
      strcpy(p->cell,c);
      code = 0;
    }
  }
    
  SETCODE(code);
  ST(0) = sv_newmortal();
  if (code==0) {
    sv_setref_pv(ST(0), "AFS::KTC_PRINCIPAL", (void*)p);
  } else {
    safefree(p);
  }
  XSRETURN(1);
 }


void
ktcp_set(p,name,...)
	AFS::KTC_PRINCIPAL	p
	char *	name
 PPCODE:
 {
  int32 code;

  if (items != 2 && items !=4) 
          croak("Usage: set($user.$inst@$cell) or set($user,$inst,$cell)");

  if (items==2) {
    code = ka_ParseLoginName(name,p->name,p->instance,p->cell);
   } else {
    STRLEN nlen, ilen, clen;
    char *i = (char *)SvPV(ST(2),ilen);
    char *c = (char *)SvPV(ST(3),clen);
    nlen = strlen(name);
    if (  nlen > MAXKTCNAMELEN-1
       || ilen > MAXKTCNAMELEN-1 
       || clen >MAXKTCREALMLEN-1) code = KABADNAME;
    else {
      strcpy(p->name,name);
      strcpy(p->instance,i);
      strcpy(p->cell,c);
      code = 0;
    }
  }
  SETCODE(code);
  EXTEND(sp,1);
  PUSHs(sv_2mortal(newSViv(code==0)));
 }

int32 
ktcp_DESTROY(p)
	AFS::KTC_PRINCIPAL	p
  CODE:
  {
     safefree(p);
     # SETCODE(0);   this spoils the ERROR code
     RETVAL = 1;
  }

void
ktcp_name(p,name=0)
	AFS::KTC_PRINCIPAL	p
	char *	name
  PPCODE:
  {
	int32 code=0;

	if (name!=0) {
	   int nlen = strlen(name);
          if (nlen > MAXKTCNAMELEN-1) code = KABADNAME;
          else strcpy(p->name, name);
          SETCODE(code);
        } 
        if (code==0) {
            EXTEND(sp,1);
            PUSHs(sv_2mortal(newSVpv(p->name,strlen(p->name))));
        }
  }

void
ktcp_instance(p,instance=0)
	AFS::KTC_PRINCIPAL	p
	char *	instance
  PPCODE:
  {
	int32 code=0;

	if (instance!=0) {
	   int ilen = strlen(instance);
          if (ilen > MAXKTCNAMELEN-1) code = KABADNAME;
          else strcpy(p->instance, instance);
          SETCODE(code);
        } 

        if (code==0) {
            EXTEND(sp,1);
            PUSHs(sv_2mortal(newSVpv(p->instance,strlen(p->instance))));
        }
  }

void
ktcp_cell(p,cell=0)
	AFS::KTC_PRINCIPAL	p
	char *	cell
  PPCODE:
  {
	int32 code=0;

	if (cell!=0) {
	   int clen = strlen(cell);
          if (clen > MAXKTCREALMLEN-1) code = KABADNAME;
          else strcpy(p->cell, cell);
          SETCODE(code);
        } 
        if (code==0) {
            EXTEND(sp,1);
            PUSHs(sv_2mortal(newSVpv(p->cell,strlen(p->cell))));
        }
  }

void
ktcp_principal(p)
	AFS::KTC_PRINCIPAL	p
  PPCODE:
  {
	int32 code=0;

        char buffer[MAXKTCNAMELEN+MAXKTCNAMELEN+MAXKTCREALMLEN+3];
        sprintf(buffer,"%s%s%s%s%s",p->name,
              p->instance[0] ? "." : "",  p->instance,
              p->cell[0] ? "@" : "", p->cell);
        EXTEND(sp,1);
        PUSHs(sv_2mortal(newSVpv(buffer,strlen(buffer))));
        SETCODE(code);
  }

MODULE = AFS		PACKAGE = AFS::KTC_TOKEN	PREFIX = ktct_

int32 
ktct_DESTROY(t)
	AFS::KTC_TOKEN	t
  CODE:
  {
     if (t && t != &the_null_token) safefree(t);
     # SETCODE(0);   this spoils the ERROR code
     RETVAL = 1;
  }

int32
ktct_startTime(t)
	AFS::KTC_TOKEN	t
  PPCODE:
    EXTEND(sp,1);
    PUSHs(sv_2mortal(newSViv(t->startTime)));

int32
ktct_endTime(t)
	AFS::KTC_TOKEN	t
  PPCODE:
    EXTEND(sp,1);
    PUSHs(sv_2mortal(newSViv(t->endTime)));

int32
ktct_kvno(t)
	AFS::KTC_TOKEN	t
  PPCODE:
    EXTEND(sp,1);
    PUSHs(sv_2mortal(newSViv(t->kvno)));

int32
ktct_ticketLen(t)
	AFS::KTC_TOKEN	t
  PPCODE:
    EXTEND(sp,1);
    PUSHs(sv_2mortal(newSViv(t->ticketLen)));

void
ktct_ticket(t)
	AFS::KTC_TOKEN	t
  PPCODE:
  {
        EXTEND(sp,1);
        PUSHs(sv_2mortal(newSVpv(t->ticket,t->ticketLen)));
  }

void
ktct_sessionKey(t)
	AFS::KTC_TOKEN	t
  PPCODE:
  {
    struct ktc_encryptionKey *key;
    SV *sv;
    key = (struct ktc_encryptionKey *) safemalloc(sizeof(*key));

    *key = t->sessionKey;
    sv = sv_newmortal();
    EXTEND(sp,1);
    sv_setref_pv(sv, "AFS::KTC_EKEY", (void*)key);
    PUSHs(sv);
  }


void
ktct_string(t)
	AFS::KTC_TOKEN	t
  PPCODE:
  {
    EXTEND(sp,1);
    PUSHs(sv_2mortal(newSVpv((char*)t,sizeof(*t))));
  }


MODULE = AFS		PACKAGE = AFS::KTC_EKEY		PREFIX = ktck_

int32 
ktck_DESTROY(k)
	AFS::KTC_EKEY	k
  CODE:
  {
     safefree(k);
     # SETCODE(0);   this spoils the ERROR code
     RETVAL = 1;
  }

void
ktck_string(k)
	AFS::KTC_EKEY	k
  PPCODE:
  {
    EXTEND(sp,1);
    PUSHs(sv_2mortal(newSVpv((char*)k,sizeof(*k))));
  }


MODULE = AFS		PACKAGE = AFS::PTS	PREFIX = pts_

AFS::PTS 
pts__new(class=0, sec=1, cell=0)
	char *	class
	int32	sec
	char *	cell
   PPCODE:
   {
	int32 code = -1;
        AFS__PTS server;

        server = internal_pts_new(&code, sec, cell);
        SETCODE(code);
          
   	ST(0) = sv_newmortal();
	if (code==0) {
	  sv_setref_pv(ST(0), "AFS::PTS", (void*)server);
        }
        XSRETURN(1);
   }

int32
pts_DESTROY(server)
	AFS::PTS server
   CODE:
   {
	int32 code;
	code = ubik_ClientDestroy(server);
        SETCODE(code);
	RETVAL = (code==0);
   }
   OUTPUT:
	RETVAL	

void
pts_id(server,object,anon=1)
	AFS::PTS server
	SV *	object
	int32	anon
   PPCODE:
   {

     if (!SvROK(object)) {
        int32 code,id;
	char *name;
       	name  = (char *)SvPV(object,PL_na);
  	code = internal_pr_id(server,name,&id,anon);
        ST(0) = sv_newmortal();
        SETCODE(code);
        if (code==0) sv_setiv(ST(0), id);
        XSRETURN(1);
     } else if (SvTYPE(SvRV(object)) == SVt_PVAV) {
	int32 code,id;
        int i,len;
        AV *av; SV *sv;
        char *name;
        STRLEN namelen;
        namelist lnames;
        idlist lids;

        av = (AV*) SvRV(object);
        len = av_len(av);
        if (len != -1)  {
          lnames.namelist_len = len+1;
          lnames.namelist_val = (prname*) safemalloc(PR_MAXNAMELEN*(len+1));
          for (i=0; i <= len; i++) {
	     sv = *av_fetch(av,i,0);
             if (sv) {
	        name = SvPV(sv,namelen); 
                strncpy(lnames.namelist_val[i],name, PR_MAXNAMELEN);
             }
	  }
          lids.idlist_len = 0;
          lids.idlist_val = 0;

          code = ubik_Call(PR_NameToID,server,0,&lnames,&lids);
          SETCODE(code);
          if (code == 0 && lids.idlist_val) {
                EXTEND(sp, lids.idlist_len);
         	for (i=0; i < lids.idlist_len; i++) {
                    id = lids.idlist_val[i];
                    if (id == ANONYMOUSID && !anon) {
                        PUSHs(sv_newmortal());
                    } else {
                        PUSHs(sv_2mortal(newSViv(id)));
		      }
                }
	        safefree(lids.idlist_val);
          }
          if (lnames.namelist_val) safefree(lnames.namelist_val);
          PUTBACK;
          return;
	}
    } else if (SvTYPE(SvRV(object)) == SVt_PVHV) {
	int32 code,id;
        int i,len;
        HV *hv; SV *sv; HE *he;
        char *name;
        STRLEN namelen;
        namelist lnames;
        idlist lids;
	char *key;
	I32 keylen;

        hv = (HV*) SvRV(object);
        len = 0;
        
        hv_iterinit(hv);
        while(hv_iternext(hv)) len++;
        if (len != 0)  {
          lnames.namelist_len = len;
          lnames.namelist_val = (prname*) safemalloc(PR_MAXNAMELEN*len);
          hv_iterinit(hv);
          i = 0;
          while(he = hv_iternext(hv)) {
                key=hv_iterkey(he, &keylen);
               strncpy(lnames.namelist_val[i],key, PR_MAXNAMELEN);
               i++;
	  }
          lids.idlist_len = 0;
          lids.idlist_val = 0;

          code = ubik_Call(PR_NameToID,server,0,&lnames,&lids);
          SETCODE(code);
          if (code == 0 && lids.idlist_val) {
                hv_iterinit(hv);
                i=0;
                while(he = hv_iternext(hv)) {
                     key=hv_iterkey(he, &keylen);
                    id = lids.idlist_val[i];
                    if (id == ANONYMOUSID && !anon) {
                        hv_store(hv, key, keylen,newSVsv(&PL_sv_undef),0);
                    } else {
                        hv_store(hv, key, keylen,newSViv(id),0);
		    }
                    i++;
                }
	        safefree(lids.idlist_val);
          }
          if (lnames.namelist_val) safefree(lnames.namelist_val);
	}
        if (code==0) {
	   ST(0) = sv_2mortal(newRV_inc((SV*)hv));
        } else {
              ST(0) = sv_newmortal();
        }

        XSRETURN(1);
    } else {
       croak("object is not a scaler, ARRAY reference, or HASH reference");
    }
   }


void
pts_PR_NameToID(server,object)
	AFS::PTS server
	SV *	object
   PPCODE:
   {


	int32 code,id;
        int i,len;
        AV *av; SV *sv;
        char *name;
        STRLEN namelen;
        namelist lnames;
        idlist lids;

        if (!SvROK(object) || SvTYPE(SvRV(object)) != SVt_PVAV) {
            croak("object is not an ARRAY reference");
        }

        av = (AV*) SvRV(object);
        len = av_len(av);
        if (len != -1)  {
          lnames.namelist_len = len+1;
          lnames.namelist_val = (prname*) safemalloc(PR_MAXNAMELEN*(len+1));
          for (i=0; i <= len; i++) {
	     sv = *av_fetch(av,i,0);
             if (sv) {
	        name = SvPV(sv,namelen); 
                strncpy(lnames.namelist_val[i],name, PR_MAXNAMELEN);
             }
	  }
          lids.idlist_len = 0;
          lids.idlist_val = 0;

          code = ubik_Call(PR_NameToID,server,0,&lnames,&lids);
          SETCODE(code);
          if (code == 0 && lids.idlist_val) {
                EXTEND(sp, lids.idlist_len);
         	for (i=0; i < lids.idlist_len; i++) {
                    id = lids.idlist_val[i];
                    PUSHs(sv_2mortal(newSViv(id)));
                }
	        safefree(lids.idlist_val);
          }
          if (lnames.namelist_val) safefree(lnames.namelist_val);
          PUTBACK;
          return;
	}
   }

void
pts_name(server,object,anon=1)
	AFS::PTS server
	SV *	object
	int32	anon
   PPCODE:
   {

     if (!SvROK(object)) {
        int32 code,id;
	char name[PR_MAXNAMELEN];
       	id  = SvIV(object);
  	code = internal_pr_name(server,id,name);
        SETCODE(code);
        ST(0) = sv_newmortal();
        if (code==0) {
           if (!anon && check_name_for_id(name, id)) {
          /* return undef */  
           } else {
               sv_setpv(ST(0), name); 
           }
        } 
        XSRETURN(1);
     } else if (SvTYPE(SvRV(object)) == SVt_PVAV) {
	int32 code,id;
        int i,len;
        AV *av; SV *sv;
        char *name;
        STRLEN namelen;
        namelist lnames;
        idlist lids;

        av = (AV*) SvRV(object);
        len = av_len(av);
        if (len != -1)  {
          lids.idlist_len = len+1;
          lids.idlist_val = (int32 *) safemalloc(sizeof(int32)*(len+1));
          lnames.namelist_len = 0;
          lnames.namelist_val = 0;
          for (i=0; i <= len; i++) {
	     sv = *av_fetch(av,i,0);
             if (sv) {
                lids.idlist_val[i] = SvIV(sv);
             }
	  }
          code = ubik_Call(PR_IDToName,server,0,&lids,&lnames);
          SETCODE(code);
          if (code == 0 && lnames.namelist_val) {
                EXTEND(sp, lnames.namelist_len);
         	for (i=0; i < lnames.namelist_len; i++) {
                    name = lnames.namelist_val[i];
                    if (!anon && check_name_for_id(name, 
                                          lids.idlist_val[i])) {
                        PUSHs(sv_newmortal());
                    } else {
                       PUSHs(sv_2mortal(newSVpv(name,strlen(name))));
                    }
                }
                safefree(lnames.namelist_val);
          }
	  if (lids.idlist_val) safefree(lids.idlist_val);
          PUTBACK;
          return;
	}
    } else if (SvTYPE(SvRV(object)) == SVt_PVHV) {
	int32 code,id;
        int i,len;
        HV *hv; SV *sv; HE *he;
        char *name;
        STRLEN namelen;
        namelist lnames;
        idlist lids;
	char *key;
	I32 keylen;

        hv = (HV*) SvRV(object);
        len = 0;
        
        hv_iterinit(hv);
        while(hv_iternext(hv)) len++;
        if (len != 0)  {
          lids.idlist_len = len;
          lids.idlist_val = (int32 *) safemalloc(sizeof(int32)*len);
          lnames.namelist_len = 0;
          lnames.namelist_val = 0;

          hv_iterinit(hv);
          i = 0;
          sv = sv_newmortal();
          while(he = hv_iternext(hv)) {
               key=hv_iterkey(he, &keylen);
		sv_setpvn(sv, key, keylen);
                lids.idlist_val[i] = SvIV(sv);
               i++;
	  }

          code = ubik_Call(PR_IDToName,server,0,&lids,&lnames);
          SETCODE(code);
          if (code == 0 && lnames.namelist_val) {
                hv_iterinit(hv);
                i=0;
                while(he = hv_iternext(hv)) {
                    key=hv_iterkey(he, &keylen);
                    name = lnames.namelist_val[i];
                    if (!anon && check_name_for_id(name, 
                                          lids.idlist_val[i])) {
                       hv_store(hv, key, keylen, newSVsv(&PL_sv_undef), 0);
                    } else  {
                       hv_store(hv, key, keylen,newSVpv(name,strlen(name)),0);
                    }
                    i++;
                }
               safefree(lnames.namelist_val);
          }
	  if (lids.idlist_val) safefree(lids.idlist_val);
	}
        if (code==0) {
	   ST(0) = sv_2mortal(newRV_inc((SV*)hv));
        } else {
              ST(0) = sv_newmortal();
        }
        XSRETURN(1);
    } else {
       croak("object is not a scaler, ARRAY reference, or HASH reference");
    }
   }

void
pts_PR_IDToName(server,object)
	AFS::PTS server
	SV *	object
   PPCODE:
   {
        int32 code,id;
        int i,len;
        AV *av; SV *sv;
        char *name;
        STRLEN namelen;
        namelist lnames;
        idlist lids;

      if (!SvROK(object) || SvTYPE(SvRV(object)) != SVt_PVAV) {
       croak("object is not an ARRAY reference");
      }

        av = (AV*) SvRV(object);
        len = av_len(av);
        if (len != -1)  {
          lids.idlist_len = len+1;
          lids.idlist_val = (int32 *) safemalloc(sizeof(int32)*(len+1));
          lnames.namelist_len = 0;
          lnames.namelist_val = 0;
          for (i=0; i <= len; i++) {
	     sv = *av_fetch(av,i,0);
             if (sv) {
                lids.idlist_val[i] = SvIV(sv);
             }
	  }
          code = ubik_Call(PR_IDToName,server,0,&lids,&lnames);
          SETCODE(code);
          if (code == 0 && lnames.namelist_val) {
                EXTEND(sp, lnames.namelist_len);
         	for (i=0; i < lnames.namelist_len; i++) {
                    name = lnames.namelist_val[i];
                    PUSHs(sv_2mortal(newSVpv(name,strlen(name))));
                }
                safefree(lnames.namelist_val);
          }
	  if (lids.idlist_val) safefree(lids.idlist_val);
          PUTBACK;
          return;
	}
   }

void
pts_members(server,name,convertids=1,over=0)
	AFS::PTS server
	char *	name
	int32	convertids
	int32	over
   PPCODE:
   {
        int32 code,wentover,id;
        int i;
        prlist list;

     code = internal_pr_id(server,name,&id,0);
     if (code==0) {
       list.prlist_val = 0;
       list.prlist_len = 0;
       code = ubik_Call(PR_ListElements,server,0,id,&list,&wentover);
       if (items==4) sv_setiv(ST(3), (IV)wentover);
       if (code==0) {
         if (convertids) {
           namelist lnames;
           lnames.namelist_len = 0;
           lnames.namelist_val = 0;
           code = ubik_Call(PR_IDToName,server,0,&list,&lnames);
           if (code == 0 && lnames.namelist_val) {
                EXTEND(sp, lnames.namelist_len);
         	for (i=0; i < lnames.namelist_len; i++) {
                    name = lnames.namelist_val[i];
                    PUSHs(sv_2mortal(newSVpv(name,strlen(name))));
                }
                safefree(lnames.namelist_val);
           }
         } else {
           EXTEND(sp, list.prlist_len);
           for (i=0; i<list.prlist_len; i++) {
              PUSHs(sv_2mortal(newSViv(list.prlist_val[i])));
           }
         }
       }
       if (list.prlist_val) safefree(list.prlist_val);
      } else {
	if (items==4) sv_setiv(ST(3), (IV)0);
     }
      SETCODE(code);
    }

void
pts_PR_ListElements(server,id,over)
	AFS::PTS server
	int32	id
	int32	over
   PPCODE:
   {
        int32 code,wentover;
        int i;
        prlist list;

       list.prlist_val = 0;
       list.prlist_len = 0;
       code = ubik_Call(PR_ListElements,server,0,id,&list,&wentover);
       sv_setiv(ST(2), (IV)wentover);
       if (code==0) {
           EXTEND(sp, list.prlist_len);
           for (i=0; i<list.prlist_len; i++) {
              PUSHs(sv_2mortal(newSViv(list.prlist_val[i])));
           }
       }
       if (list.prlist_val) safefree(list.prlist_val);
       SETCODE(code);
    }

void
pts_getcps(server,name,convertids=1,over=0)
	AFS::PTS server
	char *	name
	int32	convertids
	int32	over
   PPCODE:
   {
        int32 code,wentover,id;
        int i;
        prlist list;

     code = internal_pr_id(server,name,&id,0);
     if (code==0) {
       list.prlist_val = 0;
       list.prlist_len = 0;
       code = ubik_Call(PR_GetCPS,server,0,id,&list,&wentover);
       if (items==4) sv_setiv(ST(3), (IV)wentover);
       if (code==0) {
         if (convertids) {
           namelist lnames;
           lnames.namelist_len = 0;
           lnames.namelist_val = 0;
           code = ubik_Call(PR_IDToName,server,0,&list,&lnames);
           if (code == 0 && lnames.namelist_val) {
                EXTEND(sp, lnames.namelist_len);
         	for (i=0; i < lnames.namelist_len; i++) {
                    name = lnames.namelist_val[i];
                    PUSHs(sv_2mortal(newSVpv(name,strlen(name))));
                }
                safefree(lnames.namelist_val);
           }
         } else {
           EXTEND(sp, list.prlist_len);
           for (i=0; i<list.prlist_len; i++) {
              PUSHs(sv_2mortal(newSViv(list.prlist_val[i])));
           }
         }
       }
       if (list.prlist_val) safefree(list.prlist_val);
      } else {
	if (items==4) sv_setiv(ST(3), (IV)0);
     }
      SETCODE(code);
    }


void
pts_PR_GetCPS(server,id,over)
	AFS::PTS server
	int32	id
	int32	over
   PPCODE:
   {
        int32 code,wentover;
        int i;
        prlist list;

       list.prlist_val = 0;
       list.prlist_len = 0;
       code = ubik_Call(PR_GetCPS,server,0,id,&list,&wentover);
       sv_setiv(ST(2), (IV)wentover);
       if (code==0) {
           EXTEND(sp, list.prlist_len);
           for (i=0; i<list.prlist_len; i++) {
              PUSHs(sv_2mortal(newSViv(list.prlist_val[i])));
           }
       }
      if (list.prlist_val) safefree(list.prlist_val);
      SETCODE(code);
    }

void
pts_owned(server,name,convertids=1,over=0)
	AFS::PTS server
	char *	name
	int32	convertids
	int32	over
   PPCODE:
   {
        int32 code,wentover,id;
        int i;
        prlist list;

     code = internal_pr_id(server,name,&id,0);
     if (code==0) {
       list.prlist_val = 0;
       list.prlist_len = 0;
       code = ubik_Call(PR_ListOwned,server,0,id,&list,&wentover);
       if (items==4) sv_setiv(ST(3), (IV)wentover);
       if (code==0) {
         if (convertids) {
           namelist lnames;
           lnames.namelist_len = 0;
           lnames.namelist_val = 0;
           code = ubik_Call(PR_IDToName,server,0,&list,&lnames);
           if (code == 0 && lnames.namelist_val) {
                EXTEND(sp, lnames.namelist_len);
         	for (i=0; i < lnames.namelist_len; i++) {
                    name = lnames.namelist_val[i];
                    PUSHs(sv_2mortal(newSVpv(name,strlen(name))));
                }
                safefree(lnames.namelist_val);
           }
         } else {
           EXTEND(sp, list.prlist_len);
           for (i=0; i<list.prlist_len; i++) {
              PUSHs(sv_2mortal(newSViv(list.prlist_val[i])));
           }
         }
       }
       if (list.prlist_val) safefree(list.prlist_val);
      } else {
	if (items==4) sv_setiv(ST(3), (IV)0);
     }
      SETCODE(code);
    }

void
pts_PR_ListOwned(server,id,over)
	AFS::PTS server
	int32	id
	int32	over
   PPCODE:
   {
        int32 code,wentover;
        int i;
        prlist list;

       list.prlist_val = 0;
       list.prlist_len = 0;
       code = ubik_Call(PR_ListOwned,server,0,id,&list,&wentover);
       sv_setiv(ST(2), (IV)wentover);
       if (code==0) {
           EXTEND(sp, list.prlist_len);
           for (i=0; i<list.prlist_len; i++) {
              PUSHs(sv_2mortal(newSViv(list.prlist_val[i])));
           }
       }
       if (list.prlist_val) safefree(list.prlist_val);
       SETCODE(code);
    }

void
pts_createuser(server,name,id=0)
	AFS::PTS server
	char *	name
        int32	id
   CODE:
   {
        int32 code;
   
        if (id) {
          code = ubik_Call(PR_INewEntry,server,0,name,id,0);
        } else {
	  code = ubik_Call(PR_NewEntry, server, 0, name,PRUSER,0,&id);
        }
        SETCODE(code);
        ST(0) = sv_newmortal();
        if (code==0) {
           sv_setiv(ST(0), id);
        }

    }

void
pts_PR_NewEntry(server,name,flag,oid)
	AFS::PTS server
	char *	name
	int32	flag
        int32	oid
   CODE:
   {
        int32 code,id;
   
        code = ubik_Call(PR_NewEntry, server, 0, name,flag,oid,&id);
        SETCODE(code);
        ST(0) = sv_newmortal();
        if (code==0) {
           sv_setiv(ST(0), id);
        }
    }

void
pts_PR_INewEntry(server,name,id,oid)
	AFS::PTS server
	char *	name
	int32	id
        int32	oid
   CODE:
   {
        int32 code;
   
        code = ubik_Call(PR_INewEntry, server, 0, name,id,oid);
        SETCODE(code);
        ST(0) = sv_newmortal();
        if (code==0) {
           sv_setiv(ST(0), id);
        }
    }

void
pts_creategroup(server,name,owner=0,id=0)
	AFS::PTS server
	char *	name
	char *	owner
        int32	id
   CODE:
   {
        int32 code = 0;
	int32 oid = 0;
  
        if (owner && strcmp(owner,"0") && strcmp(owner,"")) {
	   code = internal_pr_id(server, owner,&oid, 0);
        }
        if (code==0) {
          if (id) code = ubik_Call(PR_INewEntry,server,0,name,id,oid);
          else code = ubik_Call(PR_NewEntry,server, 0, name,PRGRP,oid,&id);
        }
        SETCODE(code);

        ST(0) = sv_newmortal();
        if (code==0) {
           sv_setiv(ST(0), id);
        }
    }

void
pts_listentry(server,name,lookupids=1,convertflags=1)
	AFS::PTS server
	char *	name
	int32	lookupids
	int32	convertflags
   PPCODE:
   {
     int32 code;
     int32 id;
     struct prcheckentry entry;

     code = internal_pr_id(server,name,&id,0);     
     if (code==0) code = ubik_Call(PR_ListEntry,server,0,id,&entry);

     SETCODE(code);

     if (code==0) {
           HV *stats;
           stats = newHV();
           parse_prcheckentry(server,stats,&entry,lookupids,convertflags);
           EXTEND(sp, 1);
	   PUSHs(sv_2mortal(newRV_inc((SV*)stats)));
     }
   }


void
pts_PR_ListEntry(server,id)
	AFS::PTS server
	int32	id
   PPCODE:
   {
     int32 code;
     struct prcheckentry entry;

     code = ubik_Call(PR_ListEntry,server,0,id,&entry);

     SETCODE(code);

     if (code==0) {
           HV *stats;
           stats = newHV();
           parse_prcheckentry(server,stats,&entry,0,0);
           EXTEND(sp, 1);
	   PUSHs(sv_2mortal(newRV_inc((SV*)stats)));
     }
   }

void
pts_dumpentry(server,pos,lookupids=1,convertflags=1)
	AFS::PTS server
	int32	pos
	int32	lookupids
	int32	convertflags
   PPCODE:
   {
     int32 code;
     struct prdebugentry entry;

     code = ubik_Call(PR_DumpEntry,server,0,pos,&entry);

     SETCODE(code);

     if (code==0) {
           HV *stats;
           stats = newHV();
           parse_prdebugentry(server,stats,&entry,lookupids,convertflags);
           EXTEND(sp, 1);
	   PUSHs(sv_2mortal(newRV_inc((SV*)stats)));
     }
   }


void
pts_PR_DumpEntry(server,pos)
	AFS::PTS server
	int32	pos
   PPCODE:
   {
     int32 code;
     struct prdebugentry entry;

     code = ubik_Call(PR_DumpEntry,server,0,pos,&entry);

     SETCODE(code);

     if (code==0) {
           HV *stats;
           stats = newHV();
           parse_prdebugentry(server,stats,&entry,0,0);
           EXTEND(sp, 1);
	   PUSHs(sv_2mortal(newRV_inc((SV*)stats)));
     }
   }

void
pts_rename(server,name,newname)
	AFS::PTS server
	char *	name
	char *	newname
   PPCODE:
   {
        int32 code;
	int32 id;

        code = internal_pr_id(server,name,&id,0);     

        if (code==0) code = ubik_Call(PR_ChangeEntry,server, 0,id,newname,0,0);

        SETCODE(code);
        ST(0) = sv_2mortal(newSViv(code==0));        
        XSRETURN(1);
    }

void
pts_chown(server,name,owner)
	AFS::PTS server
	char *	name
	char *	owner
   PPCODE:
   {
        int32 code;
	int32 id,oid;

        code = internal_pr_id(server,name,&id,0);     
        if (code==0) code = internal_pr_id(server,owner,&oid,0);     
        if (code==0) code = ubik_Call(PR_ChangeEntry,server, 0,id,"",oid,0);
        SETCODE(code);
        ST(0) = sv_2mortal(newSViv(code==0));        
        XSRETURN(1);
    }

void
pts_chid(server,name,newid)
	AFS::PTS server
	char *	name
	int32	newid
   PPCODE:
   {
        int32 code;
	int32 id;

        code = internal_pr_id(server,name,&id,0);
        if (code==0) code = ubik_Call(PR_ChangeEntry,server, 0,id,"",0,newid);
        SETCODE(code);
        ST(0) = sv_2mortal(newSViv(code==0));
        XSRETURN(1);
    }

void
pts_PR_ChangeEntry(server,id,name,oid,newid)
	AFS::PTS server
	int32	id
	char *	name
	int32	oid
	int32	newid
   PPCODE:
   {
        int32 code;

	if (name && !*name) name = NULL;

        code = ubik_Call(PR_ChangeEntry,server, 0,id,name,oid,newid);

        SETCODE(code);
        ST(0) = sv_2mortal(newSViv(code==0));        
        XSRETURN(1);
    }

void
pts_adduser(server,name,group)
	AFS::PTS server
	char *	name
	char *	group
   PPCODE:
   {
	int32 code,id,gid;

        code = internal_pr_id(server,name,&id,0);
        if (code==0) code = internal_pr_id(server,group,&gid,0);     
        if (code==0) code = ubik_Call(PR_AddToGroup, server, 0, id, gid);
        SETCODE(code);

        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }


void
pts_PR_AddToGroup(server,uid,gid)
	AFS::PTS server
	int32	uid
	int32	gid
   PPCODE:
   {
	int32 code;
        code = ubik_Call(PR_AddToGroup, server, 0, uid, gid);
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }

void
pts_removeuser(server,name,group)
	AFS::PTS server
	char *	name
	char *	group
   PPCODE:
   {
	int32 code,id,gid;

        code = internal_pr_id(server,name,&id,0);
        if (code==0) code = internal_pr_id(server,group,&gid,0);     
        if (code==0) code = ubik_Call(PR_RemoveFromGroup, server, 0, id, gid);
        SETCODE(code);

        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }


void
pts_PR_RemoveFromGroup(server,uid,gid)
	AFS::PTS server
	int	uid
	int	gid
   PPCODE:
   {
	int32 code;

        code = ubik_Call(PR_RemoveFromGroup, server, 0, uid, gid);
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }

void
pts_delete(server,name)
	AFS::PTS server
	char *	name
   PPCODE:
   {
        int32 code,id;

        code = internal_pr_id(server,name,&id,0);     
        if (code==0) code = ubik_Call(PR_Delete,server,0,id);
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }


void
pts_PR_Delete(server,id)
	AFS::PTS server
	int32	id
   PPCODE:
   {
        int32 code;

        code = ubik_Call(PR_Delete,server,0,id);
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }

void
pts_whereisit(server,name)
	AFS::PTS server
	char *	name
   PPCODE:
   {
        int32 code,id,pos;

        code = internal_pr_id(server,name,&id,0);     
        if (code==0) code = ubik_Call(PR_WhereIsIt,server,0,id,&pos);
        SETCODE(code);
        ST(0) = sv_newmortal();
        if (code==0) sv_setiv(ST(0), pos);
        XSRETURN(1);
    }


void
pts_PR_WhereIsIt(server,id)
	AFS::PTS server
	int32	id
   PPCODE:
   {
        int32 code,pos;

        code = ubik_Call(PR_WhereIsIt,server,0,id,&pos);
        SETCODE(code);
        ST(0) = sv_newmortal();
        if (code==0) sv_setiv(ST(0), pos);
        XSRETURN(1);
    }

void
pts_listmax(server)
	AFS::PTS server
   PPCODE:
   {
        int32 code,uid,gid;

        code = ubik_Call(PR_ListMax,server,0,&uid,&gid);
        SETCODE(code);
        if (code==0) {
           EXTEND(sp, 2);
           PUSHs(sv_2mortal(newSViv(uid)));
           PUSHs(sv_2mortal(newSViv(gid)));
        } 
    }


void
pts_PR_ListMax(server)
	AFS::PTS server
   PPCODE:
   {
        int32 code,uid,gid;

        code = ubik_Call(PR_ListMax,server,0,&uid,&gid);
        SETCODE(code);
        if (code==0) {
           EXTEND(sp, 2);
           PUSHs(sv_2mortal(newSViv(uid)));
           PUSHs(sv_2mortal(newSViv(gid)));
        } 
    }

void
pts_setmax(server,id,isgroup=0)
	AFS::PTS server
	int32	id
	int32	isgroup
   PPCODE:
   {
        int32 code,flag;

        flag = 0;
        if (isgroup) flag |= PRGRP;
        code = ubik_Call(PR_SetMax,server,0,id,flag);
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }


void
pts_PR_SetMax(server,id,gflag)
	AFS::PTS server
	int32	id
	int32	gflag
   PPCODE:
   {
        int32 code;

        code = ubik_Call(PR_SetMax,server,0,id,gflag);
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }

void
pts_setgroupquota(server,name,ngroups)
	AFS::PTS server
	char *	name
	int32	ngroups
   PPCODE:
   {
        int32 code,id,flag,mask;

        code = internal_pr_id(server,name,&id,0);     
   
        if (code==0) {
	     mask = PR_SF_NGROUPS;
             code = ubik_Call(PR_SetFieldsEntry,server,0,
                                        id,mask,0,ngroups,0,0,0);
        }
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }


void
pts_PR_SetFieldsEntry(server,id,mask,flags,ngroups,nusers,spare1,spare2)
	AFS::PTS server
	int32	id
	int32	mask
	int32	flags
	int32	ngroups
	int32	nusers
	int32	spare1
	int32	spare2
   PPCODE:
   {
        int32 code;

        code = ubik_Call(PR_SetFieldsEntry,server,0,
                             id,mask,flags,ngroups,nusers,spare1,spare2);
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }

void
pts_setaccess(server,name,access)
	AFS::PTS server
	char *	name
	char *	access
   PPCODE:
   {
        int32 code,id,flags,mask;

        code = internal_pr_id(server,name,&id,0);     
        if (code==0) code = parse_pts_setfields(access, &flags);
        if (code==0) {
	    mask = PR_SF_ALLBITS;
            code = ubik_Call(PR_SetFieldsEntry,server,0,id,mask,flags,0,0,0,0);
        }
        SETCODE(code);
        ST(0) = sv_newmortal();
        sv_setiv(ST(0), (code==0));
        XSRETURN(1);
    }

void
pts_ismember(server,name,group)
	AFS::PTS server
	char *	name
	char *	group
   PPCODE:
   {
     int32 code,id,gid,flag;

     code = internal_pr_id(server,name,&id,0);
     if (code==0) code = internal_pr_id(server,group,&gid,0);     
     if (code==0) code = ubik_Call(PR_IsAMemberOf, server, 0, id, gid,&flag);
     SETCODE(code);
   
     ST(0) = sv_newmortal();
     if (code==0) sv_setiv(ST(0), (flag!=0));
     XSRETURN(1);
    }


void
pts_PR_IsAMemberOf(server,uid,gid)
	AFS::PTS server
	int32	uid
	int32	gid
   PPCODE:
   {
     int32 code,flag;

     code = ubik_Call(PR_IsAMemberOf, server, 0, uid, gid,&flag);
     SETCODE(code);
     ST(0) = sv_newmortal();
     if (code==0) sv_setiv(ST(0), (flag!=0));
     XSRETURN(1);
    }

MODULE = AFS		PACKAGE = AFS::KAS	PREFIX = kas_

int32
kas_DESTROY(server)
	AFS::KAS	server
   CODE:
   {
	int32 code;
  	code = ubik_ClientDestroy(server);
        SETCODE(code);
	RETVAL = (code==0);
   }
   OUTPUT:
	RETVAL	

void
kas_KAM_GetEntry(server,user,inst)
	AFS::KAS	server
	char *	user
	char *	inst
   PPCODE:
   {
	int32 code;
        struct kaentryinfo entry;

        code = ubik_Call(KAM_GetEntry, server, 0, 
                                user, inst, KAMAJORVERSION, &entry);
        SETCODE(code);
        if (code==0) {
           HV *stats = newHV();
           if (parse_kaentryinfo(stats,&entry)) {
                  EXTEND(sp,1);
                  PUSHs(sv_2mortal(newRV_inc((SV*)stats)));
           } else {
		hv_undef(stats);
           }
	}
   }

void
kas_KAM_Debug(server,version)
	AFS::KAS	server
	int32	version
   PPCODE:
   {
	int32 code;
        struct ka_debugInfo entry;

        code = ubik_Call(KAM_Debug, server, 0, version, 0, &entry);
        SETCODE(code);
        if (code==0) {
           HV *stats = newHV();
           if (parse_ka_debugInfo(stats,&entry)) {
                  EXTEND(sp,1);
                  PUSHs(sv_2mortal(newRV_inc((SV*)stats)));
           } else {
		hv_undef(stats);
           }
	}
   }

void
kas_KAM_GetStats(server,version)
	AFS::KAS	server
	int32	version
   PPCODE:
   {
	int32 code;
	int32 admin_accounts;
        struct kasstats kas;
        struct kadstats kad;

        code = ubik_Call(KAM_GetStats, server, 0, 
                        version, &admin_accounts, &kas, &kad);
        SETCODE(code);
        if (code==0) {
           HV *stats = newHV();
           HV *dstats = newHV();
           if (parse_ka_getstats(stats,dstats, &kas, &kad)) {
                  EXTEND(sp,3);
                  PUSHs(sv_2mortal(newSViv(admin_accounts)));
                  PUSHs(sv_2mortal(newRV_inc((SV*)stats)));
                  PUSHs(sv_2mortal(newRV_inc((SV*)dstats)));
           } else {
		hv_undef(stats);
		hv_undef(dstats);
           }
	}
   }

void
kas_KAM_GetRandomKey(server)
	AFS::KAS	server
   PPCODE:
   {
	int32 code;
        struct ktc_encryptionKey *key;

        key = (struct ktc_encryptionKey *) safemalloc(sizeof(*key));

        code = ubik_Call(KAM_GetRandomKey, server, 0, key);
                                
        SETCODE(code);
        if (code==0) {
            SV *st = sv_newmortal();
            sv_setref_pv(st, "AFS::KTC_EKEY", (void*)key);
            PUSHs(st);
	} else {
          safefree(key);
        }
   }

void
kas_KAM_CreateUser(server,user,inst,key)
	AFS::KAS	server
	char *	user
	char *	inst
	AFS::KTC_EKEY	key
   PPCODE:
   {
	int32 code;

        code = ubik_Call(KAM_CreateUser, server, 0, user, inst, *key);

        SETCODE(code);
        EXTEND(sp,1);
        PUSHs(sv_2mortal(newSViv(code==0)));
   }

void
kas_KAM_SetPassword(server,user,inst,kvno,key)
	AFS::KAS	server
	char *	user
	char *	inst
	int32	kvno
	AFS::KTC_EKEY	key
   PPCODE:
   {
	int32 code;

        code = ubik_Call(KAM_SetPassword, server, 0, user, inst, kvno, *key);

        SETCODE(code);
        EXTEND(sp,1);
        PUSHs(sv_2mortal(newSViv(code==0)));
   }

void
kas_KAM_DeleteUser(server,user,inst)
	AFS::KAS	server
	char *	user
	char *	inst
   PPCODE:
   {
	int32 code;

        code = ubik_Call(KAM_DeleteUser, server, 0, user, inst);
        SETCODE(code);
        EXTEND(sp,1);
        PUSHs(sv_2mortal(newSViv(code==0)));
   }

void
kas_KAM_ListEntry(server,previous,index,count)
	AFS::KAS	server
	int32	previous
	int32	index
	int32	count
   PPCODE:
   {
	int32 code;
        struct kaident ki;

        code = ubik_Call(KAM_ListEntry, server, 0,
                                previous, &index,&count, &ki);
        sv_setiv(ST(2), (IV)index);
        sv_setiv(ST(3), (IV)count);
        SETCODE(code);
        if (code==0 && count >=0) {
            EXTEND(sp,2);
            PUSHs(sv_2mortal(newSVpv(ki.name,strlen(ki.name))));
            PUSHs(sv_2mortal(newSVpv(ki.instance,strlen(ki.instance))));
	}
   }


void
kas_KAM_SetFields(server,name,instance,flags,user_expire,max_ticket_life, maxAssoc, misc_auth_bytes, spare2)
	AFS::KAS	server
	char *	name
	char *	instance
	int32	flags
	int32	user_expire
	int32	max_ticket_life
	int32	maxAssoc
        uint32  misc_auth_bytes;  /* 4 bytes, each 0 means unspecified*/
	int32	spare2
   PPCODE:
   {
	int32 code;
        struct kaident ki;

#  tpf nog 03/29/99 
#  wrong argument list: max_ticket_life was missing
#       code = ubik_Call(KAM_SetFields, server, 0, name, instance,
#		flags, user_expire, maxAssoc, spare1,spare2);        
        code = ubik_Call(KAM_SetFields, server, 0, name, instance,
		flags, user_expire, max_ticket_life, maxAssoc, misc_auth_bytes, spare2);
        SETCODE(code);
        EXTEND(sp,1);
        PUSHs(sv_2mortal(newSViv(code==0)));               
   }

void
kas_ka_ChangePassword(server,name,instance,oldkey,newkey)
	AFS::KAS	server
	char *	name
	char *	instance
	AFS::KTC_EKEY	oldkey
	AFS::KTC_EKEY	newkey
   PPCODE:
   {
	int32 code;

        code = ka_ChangePassword(name,instance,server,oldkey,newkey);
        SETCODE(code);
        EXTEND(sp,1);
        PUSHs(sv_2mortal(newSViv(code==0)));               
   }


void
kas_ka_GetToken(server,name,instance,start,end,auth_token,auth_domain="")
	AFS::KAS	server
	char *	name
	char *	instance
	int32	start
	int32	end
	AFS::KTC_TOKEN	auth_token
	char *	auth_domain
   PPCODE:
   {
	int32 code;
        struct ktc_token *t;
#if defined(AFS_3_4)
#else
        char *cname = NULL;
        char *cinst = NULL;
	char *cell  = NULL;
#endif

        t = (struct ktc_token *) safemalloc(sizeof(struct ktc_token));
#if defined(AFS_3_4)
        code = ka_GetToken(name,instance,server,start,
                           end,auth_token,auth_domain,t);
#else
	if (cell==0) cell = internal_GetLocalCell(&code);
        if (code==0) code = ka_GetToken(name,instance,cell,cname,cinst,server,
                                        start,end,auth_token,auth_domain,t);
#endif
        SETCODE(code);
        if (code==0) {
            SV *st;
            EXTEND(sp,1);
            st = sv_newmortal();
            sv_setref_pv(st, "AFS::KTC_TOKEN", (void*)t);
            PUSHs(st);
        } else {
            safefree(t);
       }
   }

void
kas_ka_Authenticate(server,name,instance,service,key,start,end,pwexpires=-1)
	AFS::KAS	server
	char *	name
	char *	instance
	int32	service
	AFS::KTC_EKEY	key
	int32	start
	int32	end
	int32	pwexpires
   PPCODE:
   {
	int32 code;
	int32 pw;
        struct ktc_token *t;
#if defined(AFS_3_4)
#else
	char *cell = NULL;
#endif

        t = (struct ktc_token *) safemalloc(sizeof(struct ktc_token));
#if defined(AFS_3_4)
        code = ka_Authenticate(name,instance,server,service,key,start,end,t,&pw);
#else
	if (cell==0) cell = internal_GetLocalCell(&code);
        if (code==0) code = ka_Authenticate(name,instance,cell,server,service,key,start,end,t,&pw);
#endif

        SETCODE(code);
        if (code==0) {
            SV *st;
            EXTEND(sp,1);
            st = sv_newmortal();
            sv_setref_pv(st, "AFS::KTC_TOKEN", (void*)t);
            PUSHs(st);
            if (pwexpires!=-1) sv_setiv(ST(7), (IV)pw);
        } else {
            safefree(t);
       }
   }

MODULE = AFS    PACKAGE = AFS   PREFIX = afs_

BOOT:
/*     initialize_bz_error_table(); */
/*     initialize_vols_error_table(); */
/*     initialize_vl_error_table(); */
    initialize_u_error_table();
    initialize_pt_error_table();
    initialize_ka_error_table();
    initialize_acfg_error_table();
    initialize_ktc_error_table();
    initialize_rxk_error_table();
/*     initialize_cmd_error_table(); */
/*     initialize_budb_error_table(); */
/*     initialize_butm_error_table(); */
/*     initialize_butc_error_table(); */


int32
afs_ascii2ptsaccess(access)
	char *	access
   CODE:
   {
	int32 code, flags;

        
        code = parse_pts_setfields(access,&flags);
	SETCODE(code);

	if (code != 0) flags=0;
	RETVAL = flags;
    }
  OUTPUT:
	RETVAL


void
afs_ptsaccess2ascii(flags)
	int32	flags
   CODE:
   {
	SETCODE(0);
	ST(0) = sv_newmortal();
	sv_setpv(ST(0), parse_flags_ptsaccess(flags));
   }

void
afs_ka_ParseLoginName(login)
	char *	login
   PPCODE:
   {
        int32 code;
        char  name[MAXKTCNAMELEN];
        char  inst[MAXKTCNAMELEN];
        char  cell[MAXKTCREALMLEN];

        code = ka_ParseLoginName (login, name, inst, cell);
        SETCODE(code);
        if (code==0) {
           EXTEND(sp, 3);
           PUSHs(sv_2mortal(newSVpv(name,strlen(name))));
           PUSHs(sv_2mortal(newSVpv(inst,strlen(inst))));
           PUSHs(sv_2mortal(newSVpv(cell,strlen(cell))));
        } 
    }

void
afs_ka_StringToKey(str,cell)
	char *	str
	char *	cell
   PPCODE:
   {
        struct ktc_encryptionKey *key;
        SV *st;

        key = (struct ktc_encryptionKey *) safemalloc(sizeof(*key));

        ka_StringToKey(str,cell, key);

        SETCODE(0);
        EXTEND(sp,1);
        st = sv_newmortal();
        sv_setref_pv(st, "AFS::KTC_EKEY", (void*)key);
        PUSHs(st);
    }

void
afs_ka_UserAthenticateGeneral(p,pass,life,flags,pwexpires=-1,reason=0)
	AFS::KTC_PRINCIPAL	p
	char *	pass
	int32	life
	int32	flags
	int32	pwexpires
	char *	reason
   PPCODE:
   {
        int32 code,pw=255;
        char *r;
        code= ka_UserAuthenticateGeneral(
              flags,
              p->name, p->instance, p->cell,
	      pass, life, &pw,0,&r);
        if (pwexpires!=-1) sv_setiv(ST(4), (IV)pw);
        if (reason) sv_setpv(ST(5),r);
        SETCODE(code);
        EXTEND(sp, 1);
        PUSHs(sv_2mortal(newSViv(code==0)));
    }

void
afs_ka_ReadPassword(prompt,verify=0,cell=0)
	char *	prompt
	int32	verify
	char *	cell
   PPCODE:
   {
	int32 code=0;
        struct ktc_encryptionKey *key;
        SV *st;

        key = (struct ktc_encryptionKey *) safemalloc(sizeof(*key));

        if (cell==0) cell = internal_GetLocalCell(&code);
        if (code==0) code = ka_ReadPassword(prompt, verify, cell, key);
        SETCODE(code);
        if (code==0) {
            EXTEND(sp,1);
            st = sv_newmortal();
            sv_setref_pv(st, "AFS::KTC_EKEY", (void*)key);
            PUSHs(st);
        } else {
	    safefree(key);
        }
    }

void
afs_ka_UserReadPassword(prompt,reason=0)
	char *	prompt
	char *	reason
   PPCODE:
   {
	int32 code;
        struct ktc_encryptionKey key;
        char buffer[1024];
        char *r;
        code = ka_UserReadPassword(prompt,buffer,sizeof(buffer)-1,&r);
        SETCODE(code);
        if (reason) sv_setpv(ST(1),r);
        if (code==0) {
            EXTEND(sp, 1);
            PUSHs(sv_2mortal(newSVpv(buffer,strlen(buffer))));
        }
    }

void
afs_ka_GetAdminToken(p,key,lifetime,newt=1,reason=0)
	AFS::KTC_PRINCIPAL  p
	AFS::KTC_EKEY	    key
	int32		    lifetime
	int32		    newt
	char *	reason
    PPCODE:
    {
	int32 code;
        struct ktc_token *t;
        char *message;

        t = (struct ktc_token *) safemalloc(sizeof(struct ktc_token));

        code = ka_GetAdminToken(p->name,p->instance,p->cell,key, lifetime, t, newt);
        SETCODE(code);

        if (code==0) {
            SV *st;
            EXTEND(sp,1);
            st = sv_newmortal();
            sv_setref_pv(st, "AFS::KTC_TOKEN", (void*)t);
            PUSHs(st);
        } else {
            safefree(t);
            switch (code) {
              case KABADREQUEST:
                message = "password was incorrect";
                break;
              case KAUBIKCALL:
                message = "Authentication Server was unavailable";
                break;
              default:
                message = (char *)error_message (code);
            }
            sv_setpv(ST(4), message);
        }

    }


void
afs_ka_GetAuthToken(p,key,lifetime,pwexpires=-1)
	AFS::KTC_PRINCIPAL p
	AFS::KTC_EKEY	   key
	int32		   lifetime
	int32		   pwexpires
    PPCODE:
    {
	int32 code;
        int32 pw;

        code = ka_GetAuthToken(p->name,p->instance,p->cell,key, lifetime, &pw);
        SETCODE(code);
        if (code==0) {
	   if (pwexpires != -1) sv_setiv(ST(3), (IV)pw);
        }
        EXTEND(sp, 1);
        PUSHs(sv_2mortal(newSViv(code==0)));

    }


void
afs_ka_GetServerToken(p,lifetime,newt=1)
	AFS::KTC_PRINCIPAL	p
	int32			lifetime
	int32			newt
    PPCODE:
    {
	int32 code;
        int32 pw;
        struct ktc_token *t;
#if defined(AFS_3_4)
#else
	int32 dosetpag;
#endif

        t = (struct ktc_token *) safemalloc(sizeof(struct ktc_token));
#if defined(AFS_3_4)
        code = ka_GetServerToken(p->name,p->instance,p->cell,lifetime,t,newt);
#else
	dosetpag=0;
        code = ka_GetServerToken(p->name,p->instance,p->cell,lifetime,t,newt,dosetpag);
#endif
        SETCODE(code);

        if (code==0) {
            SV *st;
            EXTEND(sp,1);
            st = sv_newmortal();
            sv_setref_pv(st, "AFS::KTC_TOKEN", (void*)t);
            PUSHs(st);
        } else {
            safefree(t);
        }
    }

void
afs_ka_nulltoken()
   PPCODE:
   {
     ST(0) = sv_newmortal();
     sv_setref_pv(ST(0), "AFS::KTC_TOKEN", (void*)&the_null_token);
     XSRETURN(1);
   }

void
afs_ka_AuthServerConn(token,service,cell=0)
	AFS::KTC_TOKEN	token
	int32		service
	char *		cell
    PPCODE:
    {
	int32 code;
        AFS__KAS server;

       if (token == &the_null_token) token = NULL;

       if (cell && cell[0]=='\0') cell = NULL;

       code = ka_AuthServerConn(cell, service, token, &server);
       SETCODE(code);

        if (code==0) {
            ST(0)  = sv_newmortal();
            sv_setref_pv(ST(0), "AFS::KAS", (void*)server);
            XSRETURN(1);
        }
    }


void
afs_ka_SingleServerConn(host,token,service,cell=0)
	char *		host
	AFS::KTC_TOKEN	token
	int32		service
	char *		cell
    PPCODE:
    {
	int32 code;
        AFS__KAS server;

       if (token == &the_null_token) token = NULL;

       code = ka_SingleServerConn(cell, host, service, token, &server);
       SETCODE(code);

       if (code==0) {
            ST(0)  = sv_newmortal();
            sv_setref_pv(ST(0), "AFS::KAS", (void*)server);
            XSRETURN(1);
       }
    }

void
afs_ka_des_string_to_key(str)
	char *	str
   PPCODE:
   {
        struct ktc_encryptionKey *key;
        SV *st;

        key = (struct ktc_encryptionKey *) safemalloc(sizeof(*key));

        des_string_to_key(str, key);
        SETCODE(0);
        EXTEND(sp,1);
        st = sv_newmortal();
        sv_setref_pv(st, "AFS::KTC_EKEY", (void*)key);
        PUSHs(st);
    }

int32
afs_setpag()
  CODE:
  {
  int32 code;

  code = setpag();
  SETCODE(code);  
  RETVAL =  (code==0);
  }
  OUTPUT:
	RETVAL

void
afs_expandcell(cell)
char *	cell
  CODE:
  {
  int32 code;
  struct afsconf_cell info;

  if (cell && !*cell) cell = NULL;
  code = internal_GetCellInfo(cell,0,&info);
  SETCODE(code);  
  ST(0) = sv_newmortal();
  if (code==0) {
      sv_setpv(ST(0), info.name);
  }
 }

void
afs_localcell()
  PPCODE:
  {
  int32 code;
  char *c;
  
  c = internal_GetLocalCell(&code);

  SETCODE(code);  
  ST(0) = sv_newmortal();
  if (code==0) {
      sv_setpv(ST(0), c);
  }
  XSRETURN(1);
 }

void
afs_getcellinfo(cell=0,ip=0)
	char *	cell
	int32	ip
   PPCODE:
   {
	int32 code;
        struct afsconf_cell info;

     code = internal_GetCellInfo(cell,0,&info);
     SETCODE(code);  

     if (cell && cell[0]==0) cell=0;

     if (code==0) {
             int i;
             char *h;
             XPUSHs(sv_2mortal(newSVpv(info.name,strlen(info.name))));
             for (i=0; i<info.numServers; i++) {
                if (ip==1) {
                 h = (char*)inet_ntoa(info.hostAddr[i].sin_addr);
                } else {
                    h = info.hostName[i];
                }
                XPUSHs(sv_2mortal(newSVpv(h,strlen(h))));
             }
	}
   }

int32
afs_convert_numeric_names(...)
   CODE:
   {
	int32 flag;

        if (items >1) croak("Usage: AFS::convert_numeric_names(flag)");
        if (items==1) {
           flag = (int)SvIV(ST(0));
            convert_numeric_names = (flag != 0);
        }
        RETVAL = convert_numeric_names;
    }
  OUTPUT:
	RETVAL

int32
afs_raise_exception(...)
   CODE:
   {
	int32 flag;

        if (items >1) croak("Usage: AFS::raise_exception(flag)");
        if (items==1) {
           flag = (int)SvIV(ST(0));
            raise_exception = (flag != 0);
        }
        RETVAL = raise_exception;
    }
  OUTPUT:
	RETVAL

void
afs_configdir(...)
   PPCODE:
   {
	char *value;
	int32 code;

        if (items >1) croak("Usage: AFS::configdir(dir)");

        if (items==1) {
            STRLEN len;
            value = (char*)SvPV(ST(0),len);
            if (config_dir != NULL) safefree(config_dir);
            if (cdir != NULL) {
                     afsconf_Close(cdir);
                     cdir = NULL;
            }
            config_dir = (char*) safemalloc(len+1);
            strcpy(config_dir, value);
            code = internal_GetConfigDir();
            SETCODE(code);
            ST(0) = sv_newmortal();
            sv_setiv(ST(0), (code==0));            
            XSRETURN(1);
        } else {
          code = internal_GetConfigDir();
          SETCODE(code);
          ST(0) = sv_newmortal();
          if (code==0) {
            sv_setpv(ST(0), config_dir);
          }
          XSRETURN(1);
        }
    }

  /* KTC routines */

AFS::KTC_PRINCIPAL
afs_ktc_ListTokens(context)
	int32	context
    PPCODE:
    {
	int32 code;
	struct ktc_principal *p;

        p = (struct ktc_principal *) safemalloc(sizeof(struct ktc_principal));
        code = ktc_ListTokens(context, &context, p);
        SETCODE(code);
        sv_setiv(ST(0), (IV)context);
        ST(0) = sv_newmortal();
        if (code==0) {
            sv_setref_pv(ST(0), "AFS::KTC_PRINCIPAL", (void*)p);
        } else {
            safefree(p);
        }
        XSRETURN(1);
    }

void
afs_ktc_GetToken(server)
	AFS::KTC_PRINCIPAL	server
    PPCODE:
    {
	int32 code;
	struct ktc_principal *c;
        struct ktc_token *t;

        c = (struct ktc_principal *) safemalloc(sizeof(struct ktc_principal));
        t = (struct ktc_token *) safemalloc(sizeof(struct ktc_token));

        code = ktc_GetToken(server, t, sizeof(*t),  c);
        SETCODE(code);

        if (code==0) {
            SV *st, *sc;
            EXTEND(sp,2);
            st = sv_newmortal();
            sv_setref_pv(st, "AFS::KTC_TOKEN", (void*)t);
            PUSHs(st);
            sc = sv_newmortal();
            sv_setref_pv(sc, "AFS::KTC_PRINCIPAL", (void*)c);
            PUSHs(sc);
        } else {
            safefree(c);
            safefree(t);
        }
    }

void
afs_ktc_SetToken(server,token,client,flags=0)
   AFS::KTC_PRINCIPAL	server
   AFS::KTC_TOKEN	token
   AFS::KTC_PRINCIPAL	client
   int32			flags
    PPCODE:
    {
	int32 code;
        code = ktc_SetToken(server,token,client,flags);
        SETCODE(code);
        ST(0) = sv_2mortal(newSViv(code==0));
        XSRETURN(1);
    }

void
afs_ktc_ForgetAllTokens()
    PPCODE:
    {
	int32 code;
        code = ktc_ForgetAllTokens();
        SETCODE(code);
        ST(0) = sv_2mortal(newSViv(code==0));
        XSRETURN(1);
    }

void
afs_error_message(code)
	int32	code
   PPCODE:
   {
     ST(0) = sv_newmortal();
     sv_setpv(ST(0),(char*)error_message(code));
     XSRETURN(1);
    }



  /* this function is generated automatically by constant_gen */
  /* You didn't think I would type in this crap did you? */
  /* thats what perl is for :-) */

#if defined(AFS_3_4)

void
constant(name)
	char *	name
   PPCODE:
   {
  ST(0) = sv_newmortal();

  errno = EINVAL;

  switch (name[0]) {
  case 'A':
	switch (name[1]) {
	case 'F':
		switch (name[2]) {
		case 'S':
		if (strEQ(name,"AFSCONF_FAILURE")) sv_setiv(ST(0),AFSCONF_FAILURE);
		else if (strEQ(name,"AFSCONF_FULL")) sv_setiv(ST(0),AFSCONF_FULL);
		else if (strEQ(name,"AFSCONF_NOCELL")) sv_setiv(ST(0),AFSCONF_NOCELL);
		else if (strEQ(name,"AFSCONF_NODB")) sv_setiv(ST(0),AFSCONF_NODB);
		else if (strEQ(name,"AFSCONF_NOTFOUND")) sv_setiv(ST(0),AFSCONF_NOTFOUND);
		else if (strEQ(name,"AFSCONF_SYNTAX")) sv_setiv(ST(0),AFSCONF_SYNTAX);
		else if (strEQ(name,"AFSCONF_UNKNOWN")) sv_setiv(ST(0),AFSCONF_UNKNOWN);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'N':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"ANONYMOUSID")) sv_setiv(ST(0),ANONYMOUSID);
			else return;
			break;
		case 'Y':
		if (strEQ(name,"ANYUSERID")) sv_setiv(ST(0),ANYUSERID);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'U':
		switch (name[2]) {
		case 'T':
		if (strEQ(name,"AUTHUSERID")) sv_setiv(ST(0),AUTHUSERID);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'C':
	switch (name[1]) {
	case 'O':
		switch (name[2]) {
		case 'S':
		if (strEQ(name,"COSIZE")) sv_setiv(ST(0),COSIZE);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'R':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"CROSS_CELL")) sv_setiv(ST(0),CROSS_CELL);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'K':
	switch (name[1]) {
	case 'A':
		switch (name[2]) {
		case 'A':
		if (strEQ(name,"KAANSWERTOOLONG")) sv_setiv(ST(0),KAANSWERTOOLONG);
		else if (strEQ(name,"KAASSOCUSER")) sv_setiv(ST(0),KAASSOCUSER);
			else return;
			break;
		case 'B':
		if (strEQ(name,"KABADARGUMENT")) sv_setiv(ST(0),KABADARGUMENT);
		else if (strEQ(name,"KABADCMD")) sv_setiv(ST(0),KABADCMD);
		else if (strEQ(name,"KABADCPW")) sv_setiv(ST(0),KABADCPW);
		else if (strEQ(name,"KABADCREATE")) sv_setiv(ST(0),KABADCREATE);
		else if (strEQ(name,"KABADINDEX")) sv_setiv(ST(0),KABADINDEX);
		else if (strEQ(name,"KABADKEY")) sv_setiv(ST(0),KABADKEY);
		else if (strEQ(name,"KABADNAME")) sv_setiv(ST(0),KABADNAME);
		else if (strEQ(name,"KABADPROTOCOL")) sv_setiv(ST(0),KABADPROTOCOL);
		else if (strEQ(name,"KABADREQUEST")) sv_setiv(ST(0),KABADREQUEST);
		else if (strEQ(name,"KABADSERVER")) sv_setiv(ST(0),KABADSERVER);
		else if (strEQ(name,"KABADTICKET")) sv_setiv(ST(0),KABADTICKET);
		else if (strEQ(name,"KABADUSER")) sv_setiv(ST(0),KABADUSER);
			else return;
			break;
		case 'C':
		if (strEQ(name,"KACLOCKSKEW")) sv_setiv(ST(0),KACLOCKSKEW);
		else if (strEQ(name,"KACREATEFAIL")) sv_setiv(ST(0),KACREATEFAIL);
			else return;
			break;
		case 'D':
		if (strEQ(name,"KADATABASEINCONSISTENT")) sv_setiv(ST(0),KADATABASEINCONSISTENT);
			else return;
			break;
		case 'E':
		if (strEQ(name,"KAEMPTY")) sv_setiv(ST(0),KAEMPTY);
		else if (strEQ(name,"KAEXIST")) sv_setiv(ST(0),KAEXIST);
			else return;
			break;
		case 'F':
		if (strEQ(name,"KAFADMIN")) sv_setiv(ST(0),KAFADMIN);
		else if (strEQ(name,"KAFASSOC")) sv_setiv(ST(0),KAFASSOC);
		else if (strEQ(name,"KAFASSOCROOT")) sv_setiv(ST(0),KAFASSOCROOT);
		else if (strEQ(name,"KAFFREE")) sv_setiv(ST(0),KAFFREE);
		else if (strEQ(name,"KAFNEWASSOC")) sv_setiv(ST(0),KAFNEWASSOC);
		else if (strEQ(name,"KAFNOCPW")) sv_setiv(ST(0),KAFNOCPW);
		else if (strEQ(name,"KAFNORMAL")) sv_setiv(ST(0),KAFNORMAL);
		else if (strEQ(name,"KAFNOSEAL")) sv_setiv(ST(0),KAFNOSEAL);
		else if (strEQ(name,"KAFNOTGS")) sv_setiv(ST(0),KAFNOTGS);
		else if (strEQ(name,"KAFOLDKEYS")) sv_setiv(ST(0),KAFOLDKEYS);
		else if (strEQ(name,"KAFSPECIAL")) sv_setiv(ST(0),KAFSPECIAL);
		else if (strEQ(name,"KAF_SETTABLE_FLAGS")) sv_setiv(ST(0),KAF_SETTABLE_FLAGS);
			else return;
			break;
		case 'I':
		if (strEQ(name,"KAINTERNALERROR")) sv_setiv(ST(0),KAINTERNALERROR);
		else if (strEQ(name,"KAIO")) sv_setiv(ST(0),KAIO);
			else return;
			break;
		case 'K':
		if (strEQ(name,"KAKEYCACHEINVALID")) sv_setiv(ST(0),KAKEYCACHEINVALID);
			else return;
			break;
		case 'L':
		if (strEQ(name,"KALOCKED")) sv_setiv(ST(0),KALOCKED);
			else return;
			break;
		case 'M':
		if (strEQ(name,"KAMAJORVERSION")) sv_setiv(ST(0),KAMAJORVERSION);
		else if (strEQ(name,"KAMINORVERSION")) sv_setiv(ST(0),KAMINORVERSION);
			else return;
			break;
		case 'N':
		if (strEQ(name,"KANOAUTH")) sv_setiv(ST(0),KANOAUTH);
		else if (strEQ(name,"KANOCELL")) sv_setiv(ST(0),KANOCELL);
		else if (strEQ(name,"KANOCELLS")) sv_setiv(ST(0),KANOCELLS);
		else if (strEQ(name,"KANOENT")) sv_setiv(ST(0),KANOENT);
		else if (strEQ(name,"KANOKEYS")) sv_setiv(ST(0),KANOKEYS);
		else if (strEQ(name,"KANORECURSE")) sv_setiv(ST(0),KANORECURSE);
		else if (strEQ(name,"KANOTICKET")) sv_setiv(ST(0),KANOTICKET);
		else if (strEQ(name,"KANOTSPECIAL")) sv_setiv(ST(0),KANOTSPECIAL);
		else if (strEQ(name,"KANULLPASSWORD")) sv_setiv(ST(0),KANULLPASSWORD);
			else return;
			break;
		case 'O':
		if (strEQ(name,"KAOLDINTERFACE")) sv_setiv(ST(0),KAOLDINTERFACE);
			else return;
			break;
		case 'P':
		if (strEQ(name,"KAPWEXPIRED")) sv_setiv(ST(0),KAPWEXPIRED);
			else return;
			break;
		case 'R':
		if (strEQ(name,"KAREADPW")) sv_setiv(ST(0),KAREADPW);
		else if (strEQ(name,"KAREUSED")) sv_setiv(ST(0),KAREUSED);
		else if (strEQ(name,"KARXFAIL")) sv_setiv(ST(0),KARXFAIL);
			else return;
			break;
		case 'T':
		if (strEQ(name,"KATOOMANYKEYS")) sv_setiv(ST(0),KATOOMANYKEYS);
		else if (strEQ(name,"KATOOMANYUBIKS")) sv_setiv(ST(0),KATOOMANYUBIKS);
		else if (strEQ(name,"KATOOSOON")) sv_setiv(ST(0),KATOOSOON);
			else return;
			break;
		case 'U':
		if (strEQ(name,"KAUBIKCALL")) sv_setiv(ST(0),KAUBIKCALL);
		else if (strEQ(name,"KAUBIKINIT")) sv_setiv(ST(0),KAUBIKINIT);
		else if (strEQ(name,"KAUNKNOWNKEY")) sv_setiv(ST(0),KAUNKNOWNKEY);
			else return;
			break;
		case '_':
		if (strEQ(name,"KA_ADMIN_INST")) sv_setpv(ST(0),KA_ADMIN_INST);
		else if (strEQ(name,"KA_ADMIN_NAME")) sv_setpv(ST(0),KA_ADMIN_NAME);
		else if (strEQ(name,"KA_AUTHENTICATION_SERVICE")) sv_setiv(ST(0),KA_AUTHENTICATION_SERVICE);
		else if (strEQ(name,"KA_ISLOCKED")) sv_setiv(ST(0),KA_ISLOCKED);
		else if (strEQ(name,"KA_MAINTENANCE_SERVICE")) sv_setiv(ST(0),KA_MAINTENANCE_SERVICE);
		else if (strEQ(name,"KA_NOREUSEPW")) sv_setiv(ST(0),KA_NOREUSEPW);
		else if (strEQ(name,"KA_REUSEPW")) sv_setiv(ST(0),KA_REUSEPW);
		else if (strEQ(name,"KA_TGS_NAME")) sv_setpv(ST(0),KA_TGS_NAME);
		else if (strEQ(name,"KA_TICKET_GRANTING_SERVICE")) sv_setiv(ST(0),KA_TICKET_GRANTING_SERVICE);
		else if (strEQ(name,"KA_USERAUTH_DOSETPAG")) sv_setiv(ST(0),KA_USERAUTH_DOSETPAG);
		else if (strEQ(name,"KA_USERAUTH_DOSETPAG2")) sv_setiv(ST(0),KA_USERAUTH_DOSETPAG2);
		else if (strEQ(name,"KA_USERAUTH_VERSION")) sv_setiv(ST(0),KA_USERAUTH_VERSION);
		else if (strEQ(name,"KA_USERAUTH_VERSION_MASK")) sv_setiv(ST(0),KA_USERAUTH_VERSION_MASK);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'T':
		switch (name[2]) {
		case 'C':
		if (strEQ(name,"KTC_TIME_UNCERTAINTY")) sv_setiv(ST(0),KTC_TIME_UNCERTAINTY);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'M':
	switch (name[1]) {
	case 'A':
		switch (name[2]) {
		case 'X':
		if (strEQ(name,"MAXKAKVNO")) sv_setiv(ST(0),MAXKAKVNO);
		else if (strEQ(name,"MAXKTCNAMELEN")) sv_setiv(ST(0),MAXKTCNAMELEN);
		else if (strEQ(name,"MAXKTCREALMLEN")) sv_setiv(ST(0),MAXKTCREALMLEN);
		else if (strEQ(name,"MAXKTCTICKETLEN")) sv_setiv(ST(0),MAXKTCTICKETLEN);
		else if (strEQ(name,"MAXKTCTICKETLIFETIME")) sv_setiv(ST(0),MAXKTCTICKETLIFETIME);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'I':
		switch (name[2]) {
		case 'N':
		if (strEQ(name,"MINKTCTICKETLEN")) sv_setiv(ST(0),MINKTCTICKETLEN);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'N':
	switch (name[1]) {
	case 'E':
		switch (name[2]) {
		case 'V':
		if (strEQ(name,"NEVERDATE")) sv_setiv(ST(0),NEVERDATE);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'P':
	switch (name[1]) {
	case 'R':
		switch (name[2]) {
		case 'A':
		if (strEQ(name,"PRACCESS")) sv_setiv(ST(0),PRACCESS);
			else return;
			break;
		case 'B':
		if (strEQ(name,"PRBADARG")) sv_setiv(ST(0),PRBADARG);
		else if (strEQ(name,"PRBADID")) sv_setiv(ST(0),PRBADID);
		else if (strEQ(name,"PRBADNAM")) sv_setiv(ST(0),PRBADNAM);
			else return;
			break;
		case 'C':
		if (strEQ(name,"PRCELL")) sv_setiv(ST(0),PRCELL);
		else if (strEQ(name,"PRCONT")) sv_setiv(ST(0),PRCONT);
			else return;
			break;
		case 'D':
		if (strEQ(name,"PRDBADDR")) sv_setiv(ST(0),PRDBADDR);
		else if (strEQ(name,"PRDBBAD")) sv_setiv(ST(0),PRDBBAD);
		else if (strEQ(name,"PRDBFAIL")) sv_setiv(ST(0),PRDBFAIL);
		else if (strEQ(name,"PRDBVERSION")) sv_setiv(ST(0),PRDBVERSION);
			else return;
			break;
		case 'E':
		if (strEQ(name,"PREXIST")) sv_setiv(ST(0),PREXIST);
			else return;
			break;
		case 'F':
		if (strEQ(name,"PRFOREIGN")) sv_setiv(ST(0),PRFOREIGN);
		else if (strEQ(name,"PRFREE")) sv_setiv(ST(0),PRFREE);
			else return;
			break;
		case 'G':
		if (strEQ(name,"PRGROUPEMPTY")) sv_setiv(ST(0),PRGROUPEMPTY);
		else if (strEQ(name,"PRGRP")) sv_setiv(ST(0),PRGRP);
			else return;
			break;
		case 'I':
		if (strEQ(name,"PRIDEXIST")) sv_setiv(ST(0),PRIDEXIST);
		else if (strEQ(name,"PRINCONSISTENT")) sv_setiv(ST(0),PRINCONSISTENT);
		else if (strEQ(name,"PRINST")) sv_setiv(ST(0),PRINST);
		else if (strEQ(name,"PRIVATE_SHIFT")) sv_setiv(ST(0),PRIVATE_SHIFT);
			else return;
			break;
		case 'N':
		if (strEQ(name,"PRNOENT")) sv_setiv(ST(0),PRNOENT);
		else if (strEQ(name,"PRNOIDS")) sv_setiv(ST(0),PRNOIDS);
		else if (strEQ(name,"PRNOMORE")) sv_setiv(ST(0),PRNOMORE);
		else if (strEQ(name,"PRNOTGROUP")) sv_setiv(ST(0),PRNOTGROUP);
		else if (strEQ(name,"PRNOTUSER")) sv_setiv(ST(0),PRNOTUSER);
			else return;
			break;
		case 'P':
		if (strEQ(name,"PRPERM")) sv_setiv(ST(0),PRPERM);
		else if (strEQ(name,"PRP_ADD_ANY")) sv_setiv(ST(0),PRP_ADD_ANY);
		else if (strEQ(name,"PRP_ADD_MEM")) sv_setiv(ST(0),PRP_ADD_MEM);
		else if (strEQ(name,"PRP_GROUP_DEFAULT")) sv_setiv(ST(0),PRP_GROUP_DEFAULT);
		else if (strEQ(name,"PRP_MEMBER_ANY")) sv_setiv(ST(0),PRP_MEMBER_ANY);
		else if (strEQ(name,"PRP_MEMBER_MEM")) sv_setiv(ST(0),PRP_MEMBER_MEM);
		else if (strEQ(name,"PRP_OWNED_ANY")) sv_setiv(ST(0),PRP_OWNED_ANY);
		else if (strEQ(name,"PRP_REMOVE_MEM")) sv_setiv(ST(0),PRP_REMOVE_MEM);
		else if (strEQ(name,"PRP_STATUS_ANY")) sv_setiv(ST(0),PRP_STATUS_ANY);
		else if (strEQ(name,"PRP_STATUS_MEM")) sv_setiv(ST(0),PRP_STATUS_MEM);
		else if (strEQ(name,"PRP_USER_DEFAULT")) sv_setiv(ST(0),PRP_USER_DEFAULT);
			else return;
			break;
		case 'Q':
		if (strEQ(name,"PRQUOTA")) sv_setiv(ST(0),PRQUOTA);
			else return;
			break;
		case 'S':
		if (strEQ(name,"PRSFS_ADMINISTER")) sv_setiv(ST(0),PRSFS_ADMINISTER);
		else if (strEQ(name,"PRSFS_DELETE")) sv_setiv(ST(0),PRSFS_DELETE);
		else if (strEQ(name,"PRSFS_INSERT")) sv_setiv(ST(0),PRSFS_INSERT);
		else if (strEQ(name,"PRSFS_LOCK")) sv_setiv(ST(0),PRSFS_LOCK);
		else if (strEQ(name,"PRSFS_LOOKUP")) sv_setiv(ST(0),PRSFS_LOOKUP);
		else if (strEQ(name,"PRSFS_READ")) sv_setiv(ST(0),PRSFS_READ);
		else if (strEQ(name,"PRSFS_USR0")) sv_setiv(ST(0),PRSFS_USR0);
		else if (strEQ(name,"PRSFS_USR1")) sv_setiv(ST(0),PRSFS_USR1);
		else if (strEQ(name,"PRSFS_USR2")) sv_setiv(ST(0),PRSFS_USR2);
		else if (strEQ(name,"PRSFS_USR3")) sv_setiv(ST(0),PRSFS_USR3);
		else if (strEQ(name,"PRSFS_USR4")) sv_setiv(ST(0),PRSFS_USR4);
		else if (strEQ(name,"PRSFS_USR5")) sv_setiv(ST(0),PRSFS_USR5);
		else if (strEQ(name,"PRSFS_USR6")) sv_setiv(ST(0),PRSFS_USR6);
		else if (strEQ(name,"PRSFS_USR7")) sv_setiv(ST(0),PRSFS_USR7);
		else if (strEQ(name,"PRSFS_WRITE")) sv_setiv(ST(0),PRSFS_WRITE);
		else if (strEQ(name,"PRSIZE")) sv_setiv(ST(0),PRSIZE);
		else if (strEQ(name,"PRSUCCESS")) sv_setiv(ST(0),PRSUCCESS);
			else return;
			break;
		case 'T':
		if (strEQ(name,"PRTOOMANY")) sv_setiv(ST(0),PRTOOMANY);
		else if (strEQ(name,"PRTYPE")) sv_setiv(ST(0),PRTYPE);
			else return;
			break;
		case 'U':
		if (strEQ(name,"PRUSER")) sv_setiv(ST(0),PRUSER);
			else return;
			break;
		case '_':
		if (strEQ(name,"PR_HIGHEST_OPCODE")) sv_setiv(ST(0),PR_HIGHEST_OPCODE);
		else if (strEQ(name,"PR_LOWEST_OPCODE")) sv_setiv(ST(0),PR_LOWEST_OPCODE);
		else if (strEQ(name,"PR_MAXGROUPS")) sv_setiv(ST(0),PR_MAXGROUPS);
		else if (strEQ(name,"PR_MAXLIST")) sv_setiv(ST(0),PR_MAXLIST);
		else if (strEQ(name,"PR_MAXNAMELEN")) sv_setiv(ST(0),PR_MAXNAMELEN);
		else if (strEQ(name,"PR_NUMBER_OPCODES")) sv_setiv(ST(0),PR_NUMBER_OPCODES);
		else if (strEQ(name,"PR_REMEMBER_TIMES")) sv_setiv(ST(0),PR_REMEMBER_TIMES);
		else if (strEQ(name,"PR_SF_ALLBITS")) sv_setiv(ST(0),PR_SF_ALLBITS);
		else if (strEQ(name,"PR_SF_NGROUPS")) sv_setiv(ST(0),PR_SF_NGROUPS);
		else if (strEQ(name,"PR_SF_NUSERS")) sv_setiv(ST(0),PR_SF_NUSERS);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'R':
	switch (name[1]) {
	case 'X':
		switch (name[2]) {
		case 'K':
		if (strEQ(name,"RXKADBADKEY")) sv_setiv(ST(0),RXKADBADKEY);
		else if (strEQ(name,"RXKADBADTICKET")) sv_setiv(ST(0),RXKADBADTICKET);
		else if (strEQ(name,"RXKADDATALEN")) sv_setiv(ST(0),RXKADDATALEN);
		else if (strEQ(name,"RXKADEXPIRED")) sv_setiv(ST(0),RXKADEXPIRED);
		else if (strEQ(name,"RXKADILLEGALLEVEL")) sv_setiv(ST(0),RXKADILLEGALLEVEL);
		else if (strEQ(name,"RXKADINCONSISTENCY")) sv_setiv(ST(0),RXKADINCONSISTENCY);
		else if (strEQ(name,"RXKADLEVELFAIL")) sv_setiv(ST(0),RXKADLEVELFAIL);
		else if (strEQ(name,"RXKADNOAUTH")) sv_setiv(ST(0),RXKADNOAUTH);
		else if (strEQ(name,"RXKADOUTOFSEQUENCE")) sv_setiv(ST(0),RXKADOUTOFSEQUENCE);
		else if (strEQ(name,"RXKADPACKETSHORT")) sv_setiv(ST(0),RXKADPACKETSHORT);
		else if (strEQ(name,"RXKADSEALEDINCON")) sv_setiv(ST(0),RXKADSEALEDINCON);
		else if (strEQ(name,"RXKADTICKETLEN")) sv_setiv(ST(0),RXKADTICKETLEN);
		else if (strEQ(name,"RXKADUNKNOWNKEY")) sv_setiv(ST(0),RXKADUNKNOWNKEY);
			else return;
			break;
		case '_':
		if (strEQ(name,"RX_SCINDEX_KAD")) sv_setiv(ST(0),RX_SCINDEX_KAD);
		else if (strEQ(name,"RX_SCINDEX_NULL")) sv_setiv(ST(0),RX_SCINDEX_NULL);
		else if (strEQ(name,"RX_SCINDEX_VAB")) sv_setiv(ST(0),RX_SCINDEX_VAB);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'S':
	switch (name[1]) {
	case 'Y':
		switch (name[2]) {
		case 'S':
		if (strEQ(name,"SYSADMINID")) sv_setiv(ST(0),SYSADMINID);
		else if (strEQ(name,"SYSBACKUPID")) sv_setiv(ST(0),SYSBACKUPID);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'U':
	switch (name[1]) {
	case 'B':
		switch (name[2]) {
		case 'A':
		if (strEQ(name,"UBADHOST")) sv_setiv(ST(0),UBADHOST);
		else if (strEQ(name,"UBADLOCK")) sv_setiv(ST(0),UBADLOCK);
		else if (strEQ(name,"UBADLOG")) sv_setiv(ST(0),UBADLOG);
		else if (strEQ(name,"UBADTYPE")) sv_setiv(ST(0),UBADTYPE);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'D':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"UDONE")) sv_setiv(ST(0),UDONE);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'E':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"UEOF")) sv_setiv(ST(0),UEOF);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'I':
		switch (name[2]) {
		case 'N':
		if (strEQ(name,"UINTERNAL")) sv_setiv(ST(0),UINTERNAL);
			else return;
			break;
		case 'O':
		if (strEQ(name,"UIOERROR")) sv_setiv(ST(0),UIOERROR);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'L':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"ULOGIO")) sv_setiv(ST(0),ULOGIO);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'N':
		switch (name[2]) {
		case 'H':
		if (strEQ(name,"UNHOSTS")) sv_setiv(ST(0),UNHOSTS);
			else return;
			break;
		case 'O':
		if (strEQ(name,"UNOENT")) sv_setiv(ST(0),UNOENT);
		else if (strEQ(name,"UNOQUORUM")) sv_setiv(ST(0),UNOQUORUM);
		else if (strEQ(name,"UNOSERVERS")) sv_setiv(ST(0),UNOSERVERS);
		else if (strEQ(name,"UNOTSYNC")) sv_setiv(ST(0),UNOTSYNC);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'S':
		switch (name[2]) {
		case 'Y':
		if (strEQ(name,"USYNC")) sv_setiv(ST(0),USYNC);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'T':
		switch (name[2]) {
		case 'W':
		if (strEQ(name,"UTWOENDS")) sv_setiv(ST(0),UTWOENDS);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'V':
	switch (name[1]) {
	case 'I':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"VIOCACCESS")) sv_setiv(ST(0),VIOCACCESS);
		else if (strEQ(name,"VIOCCKBACK")) sv_setiv(ST(0),VIOCCKBACK);
		else if (strEQ(name,"VIOCCKCONN")) sv_setiv(ST(0),VIOCCKCONN);
		else if (strEQ(name,"VIOCCKSERV")) sv_setiv(ST(0),VIOCCKSERV);
		else if (strEQ(name,"VIOCDISGROUP")) sv_setiv(ST(0),VIOCDISGROUP);
		else if (strEQ(name,"VIOCENGROUP")) sv_setiv(ST(0),VIOCENGROUP);
		else if (strEQ(name,"VIOCFLUSH")) sv_setiv(ST(0),VIOCFLUSH);
		else if (strEQ(name,"VIOCFLUSHCB")) sv_setiv(ST(0),VIOCFLUSHCB);
		else if (strEQ(name,"VIOCGETAL")) sv_setiv(ST(0),VIOCGETAL);
		else if (strEQ(name,"VIOCGETCACHEPARMS")) sv_setiv(ST(0),VIOCGETCACHEPARMS);
		else if (strEQ(name,"VIOCGETCELL")) sv_setiv(ST(0),VIOCGETCELL);
		else if (strEQ(name,"VIOCGETFID")) sv_setiv(ST(0),VIOCGETFID);
		else if (strEQ(name,"VIOCGETTIME")) sv_setiv(ST(0),VIOCGETTIME);
		else if (strEQ(name,"VIOCGETTOK")) sv_setiv(ST(0),VIOCGETTOK);
		else if (strEQ(name,"VIOCGETVCXSTATUS")) sv_setiv(ST(0),VIOCGETVCXSTATUS);
		else if (strEQ(name,"VIOCGETVOLSTAT")) sv_setiv(ST(0),VIOCGETVOLSTAT);
		else if (strEQ(name,"VIOCLISTGROUPS")) sv_setiv(ST(0),VIOCLISTGROUPS);
		else if (strEQ(name,"VIOCNEWCELL")) sv_setiv(ST(0),VIOCNEWCELL);
		else if (strEQ(name,"VIOCNOP")) sv_setiv(ST(0),VIOCNOP);
		else if (strEQ(name,"VIOCPREFETCH")) sv_setiv(ST(0),VIOCPREFETCH);
		else if (strEQ(name,"VIOCSETAL")) sv_setiv(ST(0),VIOCSETAL);
		else if (strEQ(name,"VIOCSETCACHESIZE")) sv_setiv(ST(0),VIOCSETCACHESIZE);
		else if (strEQ(name,"VIOCSETTOK")) sv_setiv(ST(0),VIOCSETTOK);
		else if (strEQ(name,"VIOCSETVOLSTAT")) sv_setiv(ST(0),VIOCSETVOLSTAT);
		else if (strEQ(name,"VIOCSTAT")) sv_setiv(ST(0),VIOCSTAT);
		else if (strEQ(name,"VIOCUNLOG")) sv_setiv(ST(0),VIOCUNLOG);
		else if (strEQ(name,"VIOCUNPAG")) sv_setiv(ST(0),VIOCUNPAG);
		else if (strEQ(name,"VIOCWAITFOREVER")) sv_setiv(ST(0),VIOCWAITFOREVER);
		else if (strEQ(name,"VIOCWHEREIS")) sv_setiv(ST(0),VIOCWHEREIS);
		else if (strEQ(name,"VIOC_AFS_DELETE_MT_PT")) sv_setiv(ST(0),VIOC_AFS_DELETE_MT_PT);
		else if (strEQ(name,"VIOC_AFS_MARINER_HOST")) sv_setiv(ST(0),VIOC_AFS_MARINER_HOST);
		else if (strEQ(name,"VIOC_AFS_STAT_MT_PT")) sv_setiv(ST(0),VIOC_AFS_STAT_MT_PT);
		else if (strEQ(name,"VIOC_AFS_SYSNAME")) sv_setiv(ST(0),VIOC_AFS_SYSNAME);
		else if (strEQ(name,"VIOC_EXPORTAFS")) sv_setiv(ST(0),VIOC_EXPORTAFS);
		else if (strEQ(name,"VIOC_FILE_CELL_NAME")) sv_setiv(ST(0),VIOC_FILE_CELL_NAME);
		else if (strEQ(name,"VIOC_FLUSHVOLUME")) sv_setiv(ST(0),VIOC_FLUSHVOLUME);
		else if (strEQ(name,"VIOC_GAG")) sv_setiv(ST(0),VIOC_GAG);
		else if (strEQ(name,"VIOC_GETCELLSTATUS")) sv_setiv(ST(0),VIOC_GETCELLSTATUS);
		else if (strEQ(name,"VIOC_GETSPREFS")) sv_setiv(ST(0),VIOC_GETSPREFS);
		else if (strEQ(name,"VIOC_GET_PRIMARY_CELL")) sv_setiv(ST(0),VIOC_GET_PRIMARY_CELL);
		else if (strEQ(name,"VIOC_GET_WS_CELL")) sv_setiv(ST(0),VIOC_GET_WS_CELL);
		else if (strEQ(name,"VIOC_SETCELLSTATUS")) sv_setiv(ST(0),VIOC_SETCELLSTATUS);
		else if (strEQ(name,"VIOC_SETSPREFS")) sv_setiv(ST(0),VIOC_SETSPREFS);
		else if (strEQ(name,"VIOC_TWIDDLE")) sv_setiv(ST(0),VIOC_TWIDDLE);
		else if (strEQ(name,"VIOC_VENUSLOG")) sv_setiv(ST(0),VIOC_VENUSLOG);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  default:
  	return;
  }

  errno = 0;
  XSRETURN(1);
  return;
 }

#else


void
constant(name)
	char *	name
   PPCODE:
   {
  ST(0) = sv_newmortal();

  errno = EINVAL;

  switch (name[0]) {
  case 'A':
	switch (name[1]) {
	case 'F':
		switch (name[2]) {
		case 'S':
		if (strEQ(name,"AFSCONF_FAILURE")) sv_setiv(ST(0),AFSCONF_FAILURE);
		else if (strEQ(name,"AFSCONF_FULL")) sv_setiv(ST(0),AFSCONF_FULL);
		else if (strEQ(name,"AFSCONF_NOCELL")) sv_setiv(ST(0),AFSCONF_NOCELL);
		else if (strEQ(name,"AFSCONF_NODB")) sv_setiv(ST(0),AFSCONF_NODB);
		else if (strEQ(name,"AFSCONF_NOTFOUND")) sv_setiv(ST(0),AFSCONF_NOTFOUND);
		else if (strEQ(name,"AFSCONF_SYNTAX")) sv_setiv(ST(0),AFSCONF_SYNTAX);
		else if (strEQ(name,"AFSCONF_UNKNOWN")) sv_setiv(ST(0),AFSCONF_UNKNOWN);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'N':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"ANONYMOUSID")) sv_setiv(ST(0),ANONYMOUSID);
			else return;
			break;
		case 'Y':
		if (strEQ(name,"ANYUSERID")) sv_setiv(ST(0),ANYUSERID);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'U':
		switch (name[2]) {
		case 'T':
		if (strEQ(name,"AUTHUSERID")) sv_setiv(ST(0),AUTHUSERID);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'C':
	switch (name[1]) {
	case 'O':
		switch (name[2]) {
		case 'S':
		if (strEQ(name,"COSIZE")) sv_setiv(ST(0),COSIZE);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'K':
	switch (name[1]) {
	case 'A':
		switch (name[2]) {
		case 'A':
		if (strEQ(name,"KAANSWERTOOLONG")) sv_setiv(ST(0),KAANSWERTOOLONG);
		else if (strEQ(name,"KAASSOCUSER")) sv_setiv(ST(0),KAASSOCUSER);
			else return;
			break;
		case 'B':
		if (strEQ(name,"KABADARGUMENT")) sv_setiv(ST(0),KABADARGUMENT);
		else if (strEQ(name,"KABADCMD")) sv_setiv(ST(0),KABADCMD);
		else if (strEQ(name,"KABADCPW")) sv_setiv(ST(0),KABADCPW);
		else if (strEQ(name,"KABADCREATE")) sv_setiv(ST(0),KABADCREATE);
		else if (strEQ(name,"KABADINDEX")) sv_setiv(ST(0),KABADINDEX);
		else if (strEQ(name,"KABADKEY")) sv_setiv(ST(0),KABADKEY);
		else if (strEQ(name,"KABADNAME")) sv_setiv(ST(0),KABADNAME);
		else if (strEQ(name,"KABADPROTOCOL")) sv_setiv(ST(0),KABADPROTOCOL);
		else if (strEQ(name,"KABADREQUEST")) sv_setiv(ST(0),KABADREQUEST);
		else if (strEQ(name,"KABADSERVER")) sv_setiv(ST(0),KABADSERVER);
		else if (strEQ(name,"KABADTICKET")) sv_setiv(ST(0),KABADTICKET);
		else if (strEQ(name,"KABADUSER")) sv_setiv(ST(0),KABADUSER);
			else return;
			break;
		case 'C':
		if (strEQ(name,"KACLOCKSKEW")) sv_setiv(ST(0),KACLOCKSKEW);
		else if (strEQ(name,"KACREATEFAIL")) sv_setiv(ST(0),KACREATEFAIL);
			else return;
			break;
		case 'D':
		if (strEQ(name,"KADATABASEINCONSISTENT")) sv_setiv(ST(0),KADATABASEINCONSISTENT);
			else return;
			break;
		case 'E':
		if (strEQ(name,"KAEMPTY")) sv_setiv(ST(0),KAEMPTY);
		else if (strEQ(name,"KAEXIST")) sv_setiv(ST(0),KAEXIST);
			else return;
			break;
		case 'F':
		if (strEQ(name,"KAFADMIN")) sv_setiv(ST(0),KAFADMIN);
		else if (strEQ(name,"KAFASSOC")) sv_setiv(ST(0),KAFASSOC);
		else if (strEQ(name,"KAFASSOCROOT")) sv_setiv(ST(0),KAFASSOCROOT);
		else if (strEQ(name,"KAFFREE")) sv_setiv(ST(0),KAFFREE);
		else if (strEQ(name,"KAFNEWASSOC")) sv_setiv(ST(0),KAFNEWASSOC);
		else if (strEQ(name,"KAFNOCPW")) sv_setiv(ST(0),KAFNOCPW);
		else if (strEQ(name,"KAFNORMAL")) sv_setiv(ST(0),KAFNORMAL);
		else if (strEQ(name,"KAFNOSEAL")) sv_setiv(ST(0),KAFNOSEAL);
		else if (strEQ(name,"KAFNOTGS")) sv_setiv(ST(0),KAFNOTGS);
		else if (strEQ(name,"KAFOLDKEYS")) sv_setiv(ST(0),KAFOLDKEYS);
		else if (strEQ(name,"KAFSPECIAL")) sv_setiv(ST(0),KAFSPECIAL);
		else if (strEQ(name,"KAF_SETTABLE_FLAGS")) sv_setiv(ST(0),KAF_SETTABLE_FLAGS);
			else return;
			break;
		case 'I':
		if (strEQ(name,"KAINTERNALERROR")) sv_setiv(ST(0),KAINTERNALERROR);
		else if (strEQ(name,"KAIO")) sv_setiv(ST(0),KAIO);
			else return;
			break;
		case 'K':
		if (strEQ(name,"KAKEYCACHEINVALID")) sv_setiv(ST(0),KAKEYCACHEINVALID);
			else return;
			break;
		case 'L':
		if (strEQ(name,"KALOCKED")) sv_setiv(ST(0),KALOCKED);
			else return;
			break;
		case 'M':
		if (strEQ(name,"KAMAJORVERSION")) sv_setiv(ST(0),KAMAJORVERSION);
		else if (strEQ(name,"KAMINORVERSION")) sv_setiv(ST(0),KAMINORVERSION);
			else return;
			break;
		case 'N':
		if (strEQ(name,"KANOAUTH")) sv_setiv(ST(0),KANOAUTH);
		else if (strEQ(name,"KANOCELL")) sv_setiv(ST(0),KANOCELL);
		else if (strEQ(name,"KANOCELLS")) sv_setiv(ST(0),KANOCELLS);
		else if (strEQ(name,"KANOENT")) sv_setiv(ST(0),KANOENT);
		else if (strEQ(name,"KANOKEYS")) sv_setiv(ST(0),KANOKEYS);
		else if (strEQ(name,"KANORECURSE")) sv_setiv(ST(0),KANORECURSE);
		else if (strEQ(name,"KANOTICKET")) sv_setiv(ST(0),KANOTICKET);
		else if (strEQ(name,"KANOTSPECIAL")) sv_setiv(ST(0),KANOTSPECIAL);
		else if (strEQ(name,"KANULLPASSWORD")) sv_setiv(ST(0),KANULLPASSWORD);
			else return;
			break;
		case 'O':
		if (strEQ(name,"KAOLDINTERFACE")) sv_setiv(ST(0),KAOLDINTERFACE);
			else return;
			break;
		case 'P':
		if (strEQ(name,"KAPWEXPIRED")) sv_setiv(ST(0),KAPWEXPIRED);
			else return;
			break;
		case 'R':
		if (strEQ(name,"KAREADPW")) sv_setiv(ST(0),KAREADPW);
		else if (strEQ(name,"KAREUSED")) sv_setiv(ST(0),KAREUSED);
		else if (strEQ(name,"KARXFAIL")) sv_setiv(ST(0),KARXFAIL);
			else return;
			break;
		case 'T':
		if (strEQ(name,"KATOOMANYKEYS")) sv_setiv(ST(0),KATOOMANYKEYS);
		else if (strEQ(name,"KATOOMANYUBIKS")) sv_setiv(ST(0),KATOOMANYUBIKS);
		else if (strEQ(name,"KATOOSOON")) sv_setiv(ST(0),KATOOSOON);
			else return;
			break;
		case 'U':
		if (strEQ(name,"KAUBIKCALL")) sv_setiv(ST(0),KAUBIKCALL);
		else if (strEQ(name,"KAUBIKINIT")) sv_setiv(ST(0),KAUBIKINIT);
		else if (strEQ(name,"KAUNKNOWNKEY")) sv_setiv(ST(0),KAUNKNOWNKEY);
			else return;
			break;
		case '_':
		if (strEQ(name,"KA_ADMIN_INST")) sv_setpv(ST(0),KA_ADMIN_INST);
		else if (strEQ(name,"KA_ADMIN_NAME")) sv_setpv(ST(0),KA_ADMIN_NAME);
		else if (strEQ(name,"KA_AUTHENTICATION_SERVICE")) sv_setiv(ST(0),KA_AUTHENTICATION_SERVICE);
		else if (strEQ(name,"KA_ISLOCKED")) sv_setiv(ST(0),KA_ISLOCKED);
		else if (strEQ(name,"KA_MAINTENANCE_SERVICE")) sv_setiv(ST(0),KA_MAINTENANCE_SERVICE);
		else if (strEQ(name,"KA_NOREUSEPW")) sv_setiv(ST(0),KA_NOREUSEPW);
		else if (strEQ(name,"KA_REUSEPW")) sv_setiv(ST(0),KA_REUSEPW);
		else if (strEQ(name,"KA_TGS_NAME")) sv_setpv(ST(0),KA_TGS_NAME);
		else if (strEQ(name,"KA_TICKET_GRANTING_SERVICE")) sv_setiv(ST(0),KA_TICKET_GRANTING_SERVICE);
		else if (strEQ(name,"KA_USERAUTH_DOSETPAG")) sv_setiv(ST(0),KA_USERAUTH_DOSETPAG);
		else if (strEQ(name,"KA_USERAUTH_DOSETPAG2")) sv_setiv(ST(0),KA_USERAUTH_DOSETPAG2);
		else if (strEQ(name,"KA_USERAUTH_VERSION")) sv_setiv(ST(0),KA_USERAUTH_VERSION);
		else if (strEQ(name,"KA_USERAUTH_VERSION_MASK")) sv_setiv(ST(0),KA_USERAUTH_VERSION_MASK);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'T':
		switch (name[2]) {
		case 'C':
		if (strEQ(name,"KTC_TIME_UNCERTAINTY")) sv_setiv(ST(0),KTC_TIME_UNCERTAINTY);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'M':
	switch (name[1]) {
	case 'A':
		switch (name[2]) {
		case 'X':
		if (strEQ(name,"MAXKAKVNO")) sv_setiv(ST(0),MAXKAKVNO);
		else if (strEQ(name,"MAXKTCNAMELEN")) sv_setiv(ST(0),MAXKTCNAMELEN);
		else if (strEQ(name,"MAXKTCREALMLEN")) sv_setiv(ST(0),MAXKTCREALMLEN);
		else if (strEQ(name,"MAXKTCTICKETLEN")) sv_setiv(ST(0),MAXKTCTICKETLEN);
		else if (strEQ(name,"MAXKTCTICKETLIFETIME")) sv_setiv(ST(0),MAXKTCTICKETLIFETIME);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'I':
		switch (name[2]) {
		case 'N':
		if (strEQ(name,"MINKTCTICKETLEN")) sv_setiv(ST(0),MINKTCTICKETLEN);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'N':
	switch (name[1]) {
	case 'E':
		switch (name[2]) {
		case 'V':
		if (strEQ(name,"NEVERDATE")) sv_setiv(ST(0),NEVERDATE);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'P':
	switch (name[1]) {
	case 'R':
		switch (name[2]) {
		case 'A':
		if (strEQ(name,"PRACCESS")) sv_setiv(ST(0),PRACCESS);
			else return;
			break;
		case 'B':
		if (strEQ(name,"PRBADARG")) sv_setiv(ST(0),PRBADARG);
		else if (strEQ(name,"PRBADID")) sv_setiv(ST(0),PRBADID);
		else if (strEQ(name,"PRBADNAM")) sv_setiv(ST(0),PRBADNAM);
			else return;
			break;
		case 'C':
		if (strEQ(name,"PRCELL")) sv_setiv(ST(0),PRCELL);
		else if (strEQ(name,"PRCONT")) sv_setiv(ST(0),PRCONT);
			else return;
			break;
		case 'D':
		if (strEQ(name,"PRDBADDR")) sv_setiv(ST(0),PRDBADDR);
		else if (strEQ(name,"PRDBBAD")) sv_setiv(ST(0),PRDBBAD);
		else if (strEQ(name,"PRDBFAIL")) sv_setiv(ST(0),PRDBFAIL);
		else if (strEQ(name,"PRDBVERSION")) sv_setiv(ST(0),PRDBVERSION);
			else return;
			break;
		case 'E':
		if (strEQ(name,"PREXIST")) sv_setiv(ST(0),PREXIST);
			else return;
			break;
		case 'F':
		if (strEQ(name,"PRFOREIGN")) sv_setiv(ST(0),PRFOREIGN);
		else if (strEQ(name,"PRFREE")) sv_setiv(ST(0),PRFREE);
			else return;
			break;
		case 'G':
		if (strEQ(name,"PRGROUPEMPTY")) sv_setiv(ST(0),PRGROUPEMPTY);
		else if (strEQ(name,"PRGRP")) sv_setiv(ST(0),PRGRP);
			else return;
			break;
		case 'I':
		if (strEQ(name,"PRIDEXIST")) sv_setiv(ST(0),PRIDEXIST);
		else if (strEQ(name,"PRINCONSISTENT")) sv_setiv(ST(0),PRINCONSISTENT);
		else if (strEQ(name,"PRINST")) sv_setiv(ST(0),PRINST);
		else if (strEQ(name,"PRIVATE_SHIFT")) sv_setiv(ST(0),PRIVATE_SHIFT);
			else return;
			break;
		case 'N':
		if (strEQ(name,"PRNOENT")) sv_setiv(ST(0),PRNOENT);
		else if (strEQ(name,"PRNOIDS")) sv_setiv(ST(0),PRNOIDS);
		else if (strEQ(name,"PRNOMORE")) sv_setiv(ST(0),PRNOMORE);
		else if (strEQ(name,"PRNOTGROUP")) sv_setiv(ST(0),PRNOTGROUP);
		else if (strEQ(name,"PRNOTUSER")) sv_setiv(ST(0),PRNOTUSER);
			else return;
			break;
		case 'P':
		if (strEQ(name,"PRPERM")) sv_setiv(ST(0),PRPERM);
		else if (strEQ(name,"PRP_ADD_ANY")) sv_setiv(ST(0),PRP_ADD_ANY);
		else if (strEQ(name,"PRP_ADD_MEM")) sv_setiv(ST(0),PRP_ADD_MEM);
		else if (strEQ(name,"PRP_GROUP_DEFAULT")) sv_setiv(ST(0),PRP_GROUP_DEFAULT);
		else if (strEQ(name,"PRP_MEMBER_ANY")) sv_setiv(ST(0),PRP_MEMBER_ANY);
		else if (strEQ(name,"PRP_MEMBER_MEM")) sv_setiv(ST(0),PRP_MEMBER_MEM);
		else if (strEQ(name,"PRP_OWNED_ANY")) sv_setiv(ST(0),PRP_OWNED_ANY);
		else if (strEQ(name,"PRP_REMOVE_MEM")) sv_setiv(ST(0),PRP_REMOVE_MEM);
		else if (strEQ(name,"PRP_STATUS_ANY")) sv_setiv(ST(0),PRP_STATUS_ANY);
		else if (strEQ(name,"PRP_STATUS_MEM")) sv_setiv(ST(0),PRP_STATUS_MEM);
		else if (strEQ(name,"PRP_USER_DEFAULT")) sv_setiv(ST(0),PRP_USER_DEFAULT);
			else return;
			break;
		case 'Q':
		if (strEQ(name,"PRQUOTA")) sv_setiv(ST(0),PRQUOTA);
			else return;
			break;
		case 'S':
		if (strEQ(name,"PRSFS_ADMINISTER")) sv_setiv(ST(0),PRSFS_ADMINISTER);
		else if (strEQ(name,"PRSFS_DELETE")) sv_setiv(ST(0),PRSFS_DELETE);
		else if (strEQ(name,"PRSFS_INSERT")) sv_setiv(ST(0),PRSFS_INSERT);
		else if (strEQ(name,"PRSFS_LOCK")) sv_setiv(ST(0),PRSFS_LOCK);
		else if (strEQ(name,"PRSFS_LOOKUP")) sv_setiv(ST(0),PRSFS_LOOKUP);
		else if (strEQ(name,"PRSFS_READ")) sv_setiv(ST(0),PRSFS_READ);
		else if (strEQ(name,"PRSFS_USR0")) sv_setiv(ST(0),PRSFS_USR0);
		else if (strEQ(name,"PRSFS_USR1")) sv_setiv(ST(0),PRSFS_USR1);
		else if (strEQ(name,"PRSFS_USR2")) sv_setiv(ST(0),PRSFS_USR2);
		else if (strEQ(name,"PRSFS_USR3")) sv_setiv(ST(0),PRSFS_USR3);
		else if (strEQ(name,"PRSFS_USR4")) sv_setiv(ST(0),PRSFS_USR4);
		else if (strEQ(name,"PRSFS_USR5")) sv_setiv(ST(0),PRSFS_USR5);
		else if (strEQ(name,"PRSFS_USR6")) sv_setiv(ST(0),PRSFS_USR6);
		else if (strEQ(name,"PRSFS_USR7")) sv_setiv(ST(0),PRSFS_USR7);
		else if (strEQ(name,"PRSFS_WRITE")) sv_setiv(ST(0),PRSFS_WRITE);
		else if (strEQ(name,"PRSIZE")) sv_setiv(ST(0),PRSIZE);
		else if (strEQ(name,"PRSUCCESS")) sv_setiv(ST(0),PRSUCCESS);
			else return;
			break;
		case 'T':
		if (strEQ(name,"PRTOOMANY")) sv_setiv(ST(0),PRTOOMANY);
		else if (strEQ(name,"PRTYPE")) sv_setiv(ST(0),PRTYPE);
			else return;
			break;
		case 'U':
		if (strEQ(name,"PRUSER")) sv_setiv(ST(0),PRUSER);
			else return;
			break;
		case '_':
		if (strEQ(name,"PR_HIGHEST_OPCODE")) sv_setiv(ST(0),PR_HIGHEST_OPCODE);
		else if (strEQ(name,"PR_LOWEST_OPCODE")) sv_setiv(ST(0),PR_LOWEST_OPCODE);
		else if (strEQ(name,"PR_MAXGROUPS")) sv_setiv(ST(0),PR_MAXGROUPS);
		else if (strEQ(name,"PR_MAXLIST")) sv_setiv(ST(0),PR_MAXLIST);
		else if (strEQ(name,"PR_MAXNAMELEN")) sv_setiv(ST(0),PR_MAXNAMELEN);
		else if (strEQ(name,"PR_NUMBER_OPCODES")) sv_setiv(ST(0),PR_NUMBER_OPCODES);
		else if (strEQ(name,"PR_REMEMBER_TIMES")) sv_setiv(ST(0),PR_REMEMBER_TIMES);
		else if (strEQ(name,"PR_SF_ALLBITS")) sv_setiv(ST(0),PR_SF_ALLBITS);
		else if (strEQ(name,"PR_SF_NGROUPS")) sv_setiv(ST(0),PR_SF_NGROUPS);
		else if (strEQ(name,"PR_SF_NUSERS")) sv_setiv(ST(0),PR_SF_NUSERS);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'R':
	switch (name[1]) {
	case 'X':
		switch (name[2]) {
		case 'K':
		if (strEQ(name,"RXKADBADKEY")) sv_setiv(ST(0),RXKADBADKEY);
		else if (strEQ(name,"RXKADBADTICKET")) sv_setiv(ST(0),RXKADBADTICKET);
		else if (strEQ(name,"RXKADDATALEN")) sv_setiv(ST(0),RXKADDATALEN);
		else if (strEQ(name,"RXKADEXPIRED")) sv_setiv(ST(0),RXKADEXPIRED);
		else if (strEQ(name,"RXKADILLEGALLEVEL")) sv_setiv(ST(0),RXKADILLEGALLEVEL);
		else if (strEQ(name,"RXKADINCONSISTENCY")) sv_setiv(ST(0),RXKADINCONSISTENCY);
		else if (strEQ(name,"RXKADLEVELFAIL")) sv_setiv(ST(0),RXKADLEVELFAIL);
		else if (strEQ(name,"RXKADNOAUTH")) sv_setiv(ST(0),RXKADNOAUTH);
		else if (strEQ(name,"RXKADOUTOFSEQUENCE")) sv_setiv(ST(0),RXKADOUTOFSEQUENCE);
		else if (strEQ(name,"RXKADPACKETSHORT")) sv_setiv(ST(0),RXKADPACKETSHORT);
		else if (strEQ(name,"RXKADSEALEDINCON")) sv_setiv(ST(0),RXKADSEALEDINCON);
		else if (strEQ(name,"RXKADTICKETLEN")) sv_setiv(ST(0),RXKADTICKETLEN);
		else if (strEQ(name,"RXKADUNKNOWNKEY")) sv_setiv(ST(0),RXKADUNKNOWNKEY);
			else return;
			break;
		case '_':
		if (strEQ(name,"RX_SCINDEX_KAD")) sv_setiv(ST(0),RX_SCINDEX_KAD);
		else if (strEQ(name,"RX_SCINDEX_NULL")) sv_setiv(ST(0),RX_SCINDEX_NULL);
		else if (strEQ(name,"RX_SCINDEX_VAB")) sv_setiv(ST(0),RX_SCINDEX_VAB);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'S':
	switch (name[1]) {
	case 'Y':
		switch (name[2]) {
		case 'S':
		if (strEQ(name,"SYSADMINID")) sv_setiv(ST(0),SYSADMINID);
		else if (strEQ(name,"SYSBACKUPID")) sv_setiv(ST(0),SYSBACKUPID);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'U':
	switch (name[1]) {
	case 'B':
		switch (name[2]) {
		case 'A':
		if (strEQ(name,"UBADHOST")) sv_setiv(ST(0),UBADHOST);
		else if (strEQ(name,"UBADLOCK")) sv_setiv(ST(0),UBADLOCK);
		else if (strEQ(name,"UBADLOG")) sv_setiv(ST(0),UBADLOG);
		else if (strEQ(name,"UBADTYPE")) sv_setiv(ST(0),UBADTYPE);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'D':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"UDONE")) sv_setiv(ST(0),UDONE);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'E':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"UEOF")) sv_setiv(ST(0),UEOF);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'I':
		switch (name[2]) {
		case 'N':
		if (strEQ(name,"UINTERNAL")) sv_setiv(ST(0),UINTERNAL);
			else return;
			break;
		case 'O':
		if (strEQ(name,"UIOERROR")) sv_setiv(ST(0),UIOERROR);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'L':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"ULOGIO")) sv_setiv(ST(0),ULOGIO);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'N':
		switch (name[2]) {
		case 'H':
		if (strEQ(name,"UNHOSTS")) sv_setiv(ST(0),UNHOSTS);
			else return;
			break;
		case 'O':
		if (strEQ(name,"UNOENT")) sv_setiv(ST(0),UNOENT);
		else if (strEQ(name,"UNOQUORUM")) sv_setiv(ST(0),UNOQUORUM);
		else if (strEQ(name,"UNOSERVERS")) sv_setiv(ST(0),UNOSERVERS);
		else if (strEQ(name,"UNOTSYNC")) sv_setiv(ST(0),UNOTSYNC);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'S':
		switch (name[2]) {
		case 'Y':
		if (strEQ(name,"USYNC")) sv_setiv(ST(0),USYNC);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
	case 'T':
		switch (name[2]) {
		case 'W':
		if (strEQ(name,"UTWOENDS")) sv_setiv(ST(0),UTWOENDS);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  case 'V':
	switch (name[1]) {
	case 'I':
		switch (name[2]) {
		case 'O':
		if (strEQ(name,"VIOCACCESS")) sv_setiv(ST(0),VIOCACCESS);
		else if (strEQ(name,"VIOCCKBACK")) sv_setiv(ST(0),VIOCCKBACK);
		else if (strEQ(name,"VIOCCKCONN")) sv_setiv(ST(0),VIOCCKCONN);
		else if (strEQ(name,"VIOCCKSERV")) sv_setiv(ST(0),VIOCCKSERV);
		else if (strEQ(name,"VIOCDISGROUP")) sv_setiv(ST(0),VIOCDISGROUP);
		else if (strEQ(name,"VIOCENGROUP")) sv_setiv(ST(0),VIOCENGROUP);
		else if (strEQ(name,"VIOCFLUSH")) sv_setiv(ST(0),VIOCFLUSH);
		else if (strEQ(name,"VIOCFLUSHCB")) sv_setiv(ST(0),VIOCFLUSHCB);
		else if (strEQ(name,"VIOCGETAL")) sv_setiv(ST(0),VIOCGETAL);
		else if (strEQ(name,"VIOCGETCACHEPARMS")) sv_setiv(ST(0),VIOCGETCACHEPARMS);
		else if (strEQ(name,"VIOCGETCELL")) sv_setiv(ST(0),VIOCGETCELL);
		else if (strEQ(name,"VIOCGETFID")) sv_setiv(ST(0),VIOCGETFID);
		else if (strEQ(name,"VIOCGETTIME")) sv_setiv(ST(0),VIOCGETTIME);
		else if (strEQ(name,"VIOCGETTOK")) sv_setiv(ST(0),VIOCGETTOK);
		else if (strEQ(name,"VIOCGETVCXSTATUS")) sv_setiv(ST(0),VIOCGETVCXSTATUS);
		else if (strEQ(name,"VIOCGETVOLSTAT")) sv_setiv(ST(0),VIOCGETVOLSTAT);
		else if (strEQ(name,"VIOCLISTGROUPS")) sv_setiv(ST(0),VIOCLISTGROUPS);
		else if (strEQ(name,"VIOCNEWCELL")) sv_setiv(ST(0),VIOCNEWCELL);
		else if (strEQ(name,"VIOCNOP")) sv_setiv(ST(0),VIOCNOP);
		else if (strEQ(name,"VIOCPREFETCH")) sv_setiv(ST(0),VIOCPREFETCH);
		else if (strEQ(name,"VIOCSETAL")) sv_setiv(ST(0),VIOCSETAL);
		else if (strEQ(name,"VIOCSETCACHESIZE")) sv_setiv(ST(0),VIOCSETCACHESIZE);
		else if (strEQ(name,"VIOCSETTOK")) sv_setiv(ST(0),VIOCSETTOK);
		else if (strEQ(name,"VIOCSETVOLSTAT")) sv_setiv(ST(0),VIOCSETVOLSTAT);
		else if (strEQ(name,"VIOCSTAT")) sv_setiv(ST(0),VIOCSTAT);
		else if (strEQ(name,"VIOCUNLOG")) sv_setiv(ST(0),VIOCUNLOG);
		else if (strEQ(name,"VIOCUNPAG")) sv_setiv(ST(0),VIOCUNPAG);
		else if (strEQ(name,"VIOCWAITFOREVER")) sv_setiv(ST(0),VIOCWAITFOREVER);
		else if (strEQ(name,"VIOCWHEREIS")) sv_setiv(ST(0),VIOCWHEREIS);
		else if (strEQ(name,"VIOC_AFS_DELETE_MT_PT")) sv_setiv(ST(0),VIOC_AFS_DELETE_MT_PT);
		else if (strEQ(name,"VIOC_AFS_MARINER_HOST")) sv_setiv(ST(0),VIOC_AFS_MARINER_HOST);
		else if (strEQ(name,"VIOC_AFS_STAT_MT_PT")) sv_setiv(ST(0),VIOC_AFS_STAT_MT_PT);
		else if (strEQ(name,"VIOC_AFS_SYSNAME")) sv_setiv(ST(0),VIOC_AFS_SYSNAME);
		else if (strEQ(name,"VIOC_EXPORTAFS")) sv_setiv(ST(0),VIOC_EXPORTAFS);
		else if (strEQ(name,"VIOC_FILE_CELL_NAME")) sv_setiv(ST(0),VIOC_FILE_CELL_NAME);
		else if (strEQ(name,"VIOC_FLUSHVOLUME")) sv_setiv(ST(0),VIOC_FLUSHVOLUME);
		else if (strEQ(name,"VIOC_GAG")) sv_setiv(ST(0),VIOC_GAG);
		else if (strEQ(name,"VIOC_GETCELLSTATUS")) sv_setiv(ST(0),VIOC_GETCELLSTATUS);
		else if (strEQ(name,"VIOC_GETSPREFS")) sv_setiv(ST(0),VIOC_GETSPREFS);
		else if (strEQ(name,"VIOC_GET_PRIMARY_CELL")) sv_setiv(ST(0),VIOC_GET_PRIMARY_CELL);
		else if (strEQ(name,"VIOC_GET_WS_CELL")) sv_setiv(ST(0),VIOC_GET_WS_CELL);
		else if (strEQ(name,"VIOC_SETCELLSTATUS")) sv_setiv(ST(0),VIOC_SETCELLSTATUS);
		else if (strEQ(name,"VIOC_SETSPREFS")) sv_setiv(ST(0),VIOC_SETSPREFS);
		else if (strEQ(name,"VIOC_TWIDDLE")) sv_setiv(ST(0),VIOC_TWIDDLE);
		else if (strEQ(name,"VIOC_VENUSLOG")) sv_setiv(ST(0),VIOC_VENUSLOG);
			else return;
			break;
  		default:
  			return;
  		}
  		break;
  	default:
  		return;
  	}
  	break;
  default:
  	return;
  }

  errno = 0;
  XSRETURN(1);
  return;
 }

#endif
