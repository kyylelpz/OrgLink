// Synthetic development fixtures; persisted keys deliberately match the app models.
import {createHash} from 'node:crypto';
export const VERSION = 1;
export const hash = value => createHash('sha256').update(typeof value === 'string' || value instanceof Uint8Array ? value : JSON.stringify(value)).digest('hex');
const names = ['Amihan Mercado','Isagani Villarin','Tala Buenaventura','Lakan Salcedo','Hiraya Manalo','Mayumi Soliven','Alon Escalante','Sinag Dimaano','Dalisay Ferrer','Makisig Tolentino','Ligaya Abad','Bayani Tejada','Mutya Alcaraz','Silayan Navarro','Kidlat Soriano','Luningning Pangan','Sampaguita Rosales','Habagat Mendoza','Diwa Evangelista','Bituin Cordero'];
const themes = [
  ['Circuit Makers Demo Society','cpu','Build practical electronics and computing projects through peer mentoring.','Make technology accessible through hands-on learning.','Confident student innovators serving their communities.',['Prototype useful devices','Share engineering skills']],
  ['Green Campus Demo Collective','leaf','Connect engineering students through sustainability and campus stewardship.','Turn environmental learning into practical collective action.','A resource-conscious and inclusive university community.',['Audit campus waste','Design sustainable solutions']],
  ['Bayanihan Demo Outreach Guild','heart-handshake','Plan collaborative learning and community service with respect for local partners.','Serve communities through responsible student-led outreach.','Students and communities learning together.',['Prepare accessible learning kits','Practice ethical volunteering']],
  ['Horizon Demo Leadership Circle','users','Develop thoughtful student leaders through workshops and organization practice.','Support accountable and inclusive student leadership.','Student organizations led with care and competence.',['Mentor emerging officers','Improve team communication']],
  ['Design Forge Demo Alliance','palette','Explore visual communication and human-centered engineering design.','Create clear and useful designs through constructive critique.','Creative engineering that welcomes diverse perspectives.',['Develop accessible prototypes','Share creative methods']],
];
const titles = ['Introduction to Embedded Systems','Campus Sustainability Seminar','Learning Kit Outreach Workshop','Student Leadership Bootcamp','Accessible Design Studio','Robotics Mini Challenge','Repair and Reuse Laboratory','Bayanihan Volunteer Orientation','Officer Planning Assembly','Prototype Critique Workshop','Responsible AI Seminar','Rainwater Design Sprint','Community Science Demonstration','Team Facilitation Clinic','Engineering Poster Design Lab','Circuit Debugging Workshop','Green Campus Planning Meeting','Outreach Reflection Forum','Leadership Case Competition','Design Thinking Showcase'];

export function buildDataset({seed = 'campus-demo', anchor = new Date().toISOString(), viewport = 393} = {}) {
  if (!/^[a-z][a-z0-9-]{2,30}$/.test(seed)) throw Error('Use a seed name of 3–31 lowercase letters, digits or hyphens.');
  const now = new Date(anchor); if (!Number.isFinite(+now) || !Number.isFinite(viewport) || viewport < 320 || viewport > 1200) throw Error('Invalid date or viewport.');
  const at = days => new Date(+now + days * 86400000);
  const prefix = `demo-${seed}`, docs = [], images = [], users = [], organizations = [], events = [];
  const add = (path, data) => { docs.push({path, data}); return data; };
  const image = (path, folder, field, label, icon, index) => images.push({path, folder:`orglink/${folder}`, field, publicIdField:field.replace('URL','PublicId'), label, icon, index, width:folder === 'events' ? Math.round((Math.min(viewport,960)-48)*4) : 768, height:folder === 'events' ? 736 : 768});
  const programs = ['Civil','Computer','Electrical','Electronics','Industrial','Manufacturing','Mechanical','Mechatronics'];
  for (let i=0;i<20;i++) {
    const uid = `${prefix}-student-${String(i+1).padStart(2,'0')}`;
    // Stable across runs; the registry's create-only reservation rejects collisions with real IDs.
    const studentNumber = `${now.getUTCFullYear()}${String(parseInt(hash(seed).slice(0,6),16)%9900+100).padStart(4,'0')}${String(i+1).padStart(2,'0')}`;
    const accountStatus = i<16 ? 'active' : ['pending','suspended','disabled','rejected'][i-16];
    const data = add(`users/${uid}`,{uid,email:`${uid}@orglink.example`,fullName:names[i],studentNumber,yearLevel:i%4+1,section:`${i%4+1}A`,college:'College of Engineering',program:`Bachelor of Science in ${programs[i%8]} Engineering`,platformRole:'user',accountStatus,photoURL:null,createdAt:at(-90),updatedAt:at(-90)});
    users.push(data);
    add(`studentIds/${studentNumber}`,{uid,state:'active',createdAt:at(-90),updatedAt:at(-90)});
    image(`users/${uid}`,'profiles','photoURL',names[i],'user-round',i);
  }
  for(let i=0;i<5;i++) {
    const [name,icon,description,mission,vision,goals] = themes[i], organizationId = `${prefix}-org-${i+1}`;
    const manager = users[i];
    const data = add(`organizations/${organizationId}`,{organizationId,name,description:`${description} Fictional demonstration organization.`,mission,vision,goals,visibility:i===2?'private':'public',status:'active',managerUid:manager.uid,logoURL:null,membershipRequirements:['Complete your student profile','Agree to respectful participation'],approvalSettings:{acceptsRequests:i!==2,mode:'manual'},positions:['President','Secretary','Programs Officer','General Member'],publicOfficers:[],createdAt:at(-80),updatedAt:at(-80)});
    organizations.push(data); image(`organizations/${organizationId}`,'organizations','logoURL',name,icon,20+i);
    // Each organization has five active participants besides its manager; 8 officers overall.
    const members = [manager,...Array.from({length:5},(_,j)=>users[5+(i+j)%11])];
    for(let j=0;j<members.length;j++) {
      const user=members[j], officer=j>0 && j<=(i<3?2:1);
      add(`organizations/${organizationId}/memberships/${user.uid}`,{uid:user.uid,organizationId,membershipRole:j===0?'manager':officer?'officer':'member',membershipStatus:'active',positionTitle:j===0?'Organization Manager':officer?(j===1?'Programs Officer':'Secretary'):'General Member',permissions:j===0?{viewRoster:true}:officer?{manageEvents:j===1,manageAttendance:true,viewRoster:true}:{},applicantName:user.fullName,requestedAt:at(-75),joinedAt:at(-74),updatedAt:at(-74),reviewedAt:at(-74),reviewedBy:manager.uid});
      if(officer) data.publicOfficers.push({name:user.fullName,positionTitle:j===1?'Programs Officer':'Secretary'});
    }
    const user=users[16+i%4];
    add(`organizations/${organizationId}/memberships/${user.uid}`,{uid:user.uid,organizationId,membershipRole:'member',membershipStatus:['pending','rejected','removed','pending','rejected'][i],positionTitle:'General Member',permissions:{},applicantName:user.fullName,requestedAt:at(-12),joinedAt:i===2?at(-11):null,updatedAt:at(-10),reviewedAt:i===0||i===3?null:at(-10),reviewedBy:i===0||i===3?null:manager.uid});
  }
  // One additional removed membership brings the total to 36, without granting access.
  add(`organizations/${organizations[0].organizationId}/memberships/${users[15].uid}`,{uid:users[15].uid,organizationId:organizations[0].organizationId,membershipRole:'member',membershipStatus:'removed',positionTitle:'General Member',permissions:{},applicantName:users[15].fullName,requestedAt:at(-70),joinedAt:at(-69),updatedAt:at(-30),reviewedAt:at(-69),reviewedBy:users[0].uid});
  for(let i=0;i<20;i++) {
    const org=organizations[i%5], eventId=`${prefix}-event-${String(i+1).padStart(2,'0')}`, path=`organizations/${org.organizationId}/events/${eventId}`;
    const category=i<6?'past':i<8?'ongoing':i<16?'upcoming':'other';
    const startAt=i<6?at(-24+i*3):i<8?at(-2/24):at(i-5);
    const endAt=new Date(+startAt+4*3600000), deadline=new Date(+startAt-3600000);
    const special=i-16, approved=i<16||special===3;
    const eventStatus=i<6?'completed':i<16?'published':special===3?'cancelled':'draft';
    const approvalStatus=approved?'approved':special===2?'rejected':'pending';
    const submittedAt=i===16?null:at(-45), reviewedAt=approved||special===2?at(-44):null;
    const data=add(path,{eventId,organizationId:org.organizationId,title:titles[i],description:`${titles[i]} brings together fictional demo students for guided practice, discussion and collaborative learning. This is a synthetic development event.`,posterURL:null,startAt,endAt,venue:['Innovation Laboratory','Engineering Seminar Hall','Community Learning Room','Student Activity Center','Design Studio'][i%5],capacity:30+i,registrationDeadline:deadline,registrationCount:0,eventStatus,approvalStatus,createdBy:org.managerUid,createdAt:at(-50),updatedAt:i<6?endAt:at(-40),visibility:org.visibility==='private'||i%3===0?'private':'public',submittedAt,reviewedAt,reviewedBy:reviewedAt?org.managerUid:null,publishedAt:approved?at(-43):null,cancelledAt:special===3?at(-2):null,completedAt:i<6?endAt:null,archivedAt:null});
    if(i%2===0)data.createdBy=docs.find(d=>d.path.startsWith(`organizations/${org.organizationId}/memberships/`)&&d.data.membershipRole==='officer'&&d.data.permissions.manageEvents===true).data.uid;
    events.push({path,data,category}); image(path,'events','posterURL',titles[i],themes[i%5][1],25+i);
    if(i>=16) continue;
    const participants=docs.filter(d=>d.path.startsWith(`organizations/${org.organizationId}/memberships/`)&&d.data.membershipStatus==='active'&&d.data.uid!==org.managerUid).slice(0,i<8?3:2);
    for(let j=0;j<participants.length;j++) {
      const uid=participants[j].data.uid, user=users.find(u=>u.uid===uid), registeredAt=at(-35);
      add(`${path}/registrations/${uid}`,{uid,eventId,organizationId:org.organizationId,registrationStatus:'registered',registeredAt,updatedAt:registeredAt});
      add(`${path}/participantIdentities/${uid}`,{uid,fullName:user.fullName,updatedAt:registeredAt});data.registrationCount++;
      if(i<6 || i<8&&j===0) add(`${path}/attendance/${uid}`,{uid,eventId,organizationId:org.organizationId,attendanceStatus:j===2?'absent':'present',verifiedAt:new Date(+startAt+3600000),verifiedBy:org.managerUid,verificationMethod:'manual'});
    }
  }
  // Two withdrawals remain visible in history and do not inflate registered counters.
  for(const event of events.slice(8,10)) {
    const org=organizations.find(o=>o.organizationId===event.data.organizationId), member=docs.filter(d=>d.path.startsWith(`organizations/${org.organizationId}/memberships/`)&&d.data.membershipStatus==='active'&&d.data.uid!==org.managerUid)[4].data;
    add(`${event.path}/registrations/${member.uid}`,{uid:member.uid,eventId:event.data.eventId,organizationId:org.organizationId,registrationStatus:'cancelled',registeredAt:at(-5),updatedAt:at(-1)});
    add(`${event.path}/participantIdentities/${member.uid}`,{uid:member.uid,fullName:member.applicantName,updatedAt:at(-1)});
  }
  return {version:VERSION,seed,anchor:now.toISOString(),viewport,users,organizations,events,docs,images};
}
export function summary(plan) {
  const count=part=>plan.docs.filter(d=>d.path.includes(`/${part}/`)).length;
  return {project:'orglink-dev',seed:plan.seed,anchor:plan.anchor,accounts:plan.users.length,organizations:plan.organizations.length,memberships:count('memberships'),officers:plan.docs.filter(d=>d.data.membershipRole==='officer').length,events:plan.events.length,eventDistribution:Object.fromEntries(['past','ongoing','upcoming','other'].map(k=>[k,plan.events.filter(e=>e.category===k).length])),registrations:count('registrations'),attendance:count('attendance'),images:plan.images.length,posterDimensions:[plan.images.at(-1).width,736]};
}
