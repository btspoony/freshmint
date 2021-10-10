const fs = require("fs-extra");
const path = require("path");
const Handlebars = require("handlebars");
const simpleGit = require("simple-git/promise");
const generateWebAssets = require("./generate-web");
const { writeFile } = require("./helpers");

async function generateProject(projectName, formattedContractName) {
  await createScaffold(projectName);

  await createContract(projectName, formattedContractName);

  await createSetupTransaction(projectName, formattedContractName);
  await createMintTransaction(projectName, formattedContractName);
  await createClaimTransaction(projectName, formattedContractName);
  await createStartDropTransaction(projectName, formattedContractName);
  await createRemoveDropTransaction(projectName, formattedContractName);

  await createGetNFTScript(projectName, formattedContractName);
  await createGetDropScript(projectName, formattedContractName);

  await createFlowConfig(projectName, formattedContractName);
  await createFlowTestnetConfig(projectName, formattedContractName);
  await createFlowMainnetConfig(projectName, formattedContractName);

  await createWebAssets(projectName, formattedContractName);
  await createReadme(projectName, formattedContractName);
  await createGitRepo(projectName);
}

async function createScaffold(dir) {
  await fs.copy(
    path.resolve(__dirname, "templates/assets"),
    path.resolve(dir, "assets")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/ipfs-data"),
    path.resolve(dir, "ipfs-data")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/mint-data"),
    path.resolve(dir, "mint-data")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/cadence/contracts/NonFungibleToken.cdc"),
    path.resolve(dir, "cadence/contracts/NonFungibleToken.cdc")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/cadence/contracts/FungibleToken.cdc"),
    path.resolve(dir, "cadence/contracts/FungibleToken.cdc")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/cadence/contracts/FlowToken.cdc"),
    path.resolve(dir, "cadence/contracts/FlowToken.cdc")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/fresh.config.js"),
    path.resolve(dir, "fresh.config.js")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/env.template"),
    path.resolve(dir, ".env")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/nfts.csv"),
    path.resolve(dir, "nfts.csv")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/docker-compose.yml"),
    path.resolve(dir, "docker-compose.yml")
  );

  await fs.copy(
    path.resolve(__dirname, "templates/gitignore"),
    path.resolve(dir, ".gitignore")
  );
}

async function createContract(dir, name) {
  const nftTemplate = await fs.readFile(
    path.resolve(__dirname, "templates/cadence/contracts/NFT.cdc"),
    "utf8"
  );

  const template = Handlebars.compile(nftTemplate);

  const result = template({ name });

  await writeFile(path.resolve(dir, `cadence/contracts/${name}.cdc`), result);
}

async function createSetupTransaction(dir, name) {
  const nftTemplate = await fs.readFile(
    path.resolve(__dirname, "templates/cadence/transactions/setup_account.cdc"),
    "utf8"
  );

  const template = Handlebars.compile(nftTemplate);

  const result = template({ name });

  await writeFile(
    path.resolve(dir, "cadence/transactions/setup_account.cdc"),
    result
  );
}

async function createMintTransaction(dir, name) {
  const nftTemplate = await fs.readFile(
    path.resolve(__dirname, "templates/cadence/transactions/mint_nft.cdc"),
    "utf8"
  );

  const template = Handlebars.compile(nftTemplate);

  const result = template({ name });

  await writeFile(path.resolve(dir, "cadence/transactions/mint.cdc"), result);
}

async function createClaimTransaction(dir, name) {
  const src = await fs.readFile(
    path.resolve(__dirname, "templates/cadence/transactions/claim_nft.cdc"),
    "utf8"
  );

  const template = Handlebars.compile(src);

  const result = template({ name });

  await writeFile(
    path.resolve(dir, "cadence/transactions/claim_nft.cdc"),
    result
  );
}

async function createStartDropTransaction(dir, name) {
  const src = await fs.readFile(
    path.resolve(__dirname, "templates/cadence/transactions/start_drop.cdc"),
    "utf8"
  );

  const template = Handlebars.compile(src);

  const result = template({ name });

  await writeFile(
    path.resolve(dir, "cadence/transactions/start_drop.cdc"),
    result
  );
}

async function createRemoveDropTransaction(dir, name) {
  const src = await fs.readFile(
    path.resolve(__dirname, "templates/cadence/transactions/remove_drop.cdc"),
    "utf8"
  );

  const template = Handlebars.compile(src);

  const result = template({ name });

  await writeFile(
    path.resolve(dir, "cadence/transactions/remove_drop.cdc"),
    result
  );
}

async function createGetNFTScript(dir, name) {
  const nftTemplate = await fs.readFile(
    path.resolve(__dirname, "templates/cadence/scripts/get_nft.cdc"),
    "utf8"
  );

  const template = Handlebars.compile(nftTemplate);

  const result = template({ name });

  await writeFile(path.resolve(dir, `cadence/scripts/get_nft.cdc`), result);
}

async function createGetDropScript(dir, name) {
  const src = await fs.readFile(
    path.resolve(__dirname, "templates/cadence/scripts/get_drop.cdc"),
    "utf8"
  );

  const template = Handlebars.compile(src);

  const result = template({ name });

  await writeFile(path.resolve(dir, `cadence/scripts/get_drop.cdc`), result);
}

async function createFlowConfig(dir, name) {
  const configTemplate = await fs.readFile(
    path.resolve(__dirname, "templates/flow.json"),
    "utf8"
  );

  const template = Handlebars.compile(configTemplate);

  const result = template({ name });

  await writeFile(path.resolve(dir, "flow.json"), result);
}

async function createFlowTestnetConfig(dir, name) {
  const configTemplate = await fs.readFile(
    path.resolve(__dirname, "templates/flow.testnet.json"),
    "utf8"
  );

  const template = Handlebars.compile(configTemplate);

  const result = template({ name });

  await writeFile(path.resolve(dir, "flow.testnet.json"), result);
}

async function createFlowMainnetConfig(dir, name) {
  const configTemplate = await fs.readFile(
    path.resolve(__dirname, "templates/flow.mainnet.json"),
    "utf8"
  );

  const template = Handlebars.compile(configTemplate);

  const result = template({ name });

  await writeFile(path.resolve(dir, "flow.mainnet.json"), result);
}

async function createReadme(dir, name) {
  const readmeTemplate = await fs.readFile(
    path.resolve(__dirname, "templates/README.md"),
    "utf8"
  );

  const template = Handlebars.compile(readmeTemplate);

  const result = template({ name });

  await writeFile(path.resolve(dir, "README.md"), result);
}

async function createWebAssets(dir, name) {
  await generateWebAssets(dir, name);
}

async function createGitRepo(dir) {
  const git = simpleGit(path.resolve(dir));
  await git.init();
  await git.add(path.resolve(dir + "/*"));
  await git.commit(`✨ Initial commit.`);
}

module.exports = generateProject;
