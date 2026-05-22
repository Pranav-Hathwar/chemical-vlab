// Promote an existing user to admin by email.
//   node scripts/promote-admin.js someone@example.com
require('dotenv').config();
const prisma = require('../src/prisma');

async function main() {
  const email = (process.argv[2] || '').toLowerCase();
  if (!email) {
    console.error('Usage: node scripts/promote-admin.js <email>');
    process.exit(1);
  }
  const user = await prisma.user.update({
    where: { email },
    data: { role: 'admin' },
  });
  console.log(`✓ ${user.email} is now an admin.`);
}

main()
  .catch((e) => {
    console.error(e.message);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
