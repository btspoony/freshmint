import NonFungibleToken from {{{ imports.NonFungibleToken }}}
import MetadataViews from {{{ imports.MetadataViews }}}
import FungibleToken from {{{ imports.FungibleToken }}}
import FreshmintMetadataViews from {{{ imports.FreshmintMetadataViews }}}

pub contract {{ contractName }}: NonFungibleToken {

    pub let version: String

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, metadataHash: [UInt8])
    pub event Revealed(id: UInt64)
    pub event Burned(id: UInt64)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    // totalSupply
    // The total number of {{ contractName }} that have been minted
    //
    pub var totalSupply: UInt64

    // A placeholder image used to display NFTs that have not
    // yet been revealed.
    pub let placeholderImage: String

    pub struct Metadata {

        // A salt that is published when the metadata is revealed.
        //
        // The salt is a byte array that is prepended to the 
        // encoded metadata values before generating the metadata hash.
        pub let metadataSalt: [UInt8]

        {{#each fields}}
        pub let {{ this.name }}: {{ this.asCadenceTypeString }}
        {{/each}}

        init(
            metadataSalt: [UInt8],
            {{#each fields}}
            {{ this.name }}: {{ this.asCadenceTypeString }},
            {{/each}}
        ) {
            self.metadataSalt = metadataSalt

            {{#each fields}}
            self.{{ this.name }} = {{ this.name }}
            {{/each}}
        }

        // Encode this metadata object as a byte array.
        //
        // This can be used to hash the metadata and verify its integrity.
        pub fun encode(): [UInt8] {
            return self.metadataSalt
            {{#each fields}}
                .concat(self.{{ this.name }}.{{ this.getCadenceByteTemplate }})
            {{/each}}
        }

        pub fun hash(): [UInt8] {
            return HashAlgorithm.SHA3_256.hash(self.encode())
        }
    }

    access(contract) let metadata: {UInt64: Metadata}

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64

        // A hash of the NFT's metadata.
        //
        // The metadata hash is known at mint time and 
        // is generated by hashing the set of metadata fields
        // for this NFT. The hash can later be used to verify
        // that the correct metadata fields are revealed.
        pub let metadataHash: [UInt8]

        init(metadataHash: [UInt8]) {
            self.id = self.uuid
            self.metadataHash = metadataHash
        }

        // Return the metadata for this NFT.
        //
        // This function returns nil if the NFT metadata has
        // not yet been revealed.
        pub fun getMetadata(): Metadata? {
            return {{ contractName }}.metadata[self.id]
        }

        pub fun getViews(): [Type] {
            if self.getMetadata() != nil {
                {{#if views }}
                return [
                    {{#each views}}
                    {{{ this.cadenceTypeString }}}{{#unless @last }},{{/unless}}
                    {{/each}}
                ]
                {{ else }}
                return []
                {{/if}}
            }

            return [
                {{#each views}}
                {{#unless this.requiresMetadata }}
                {{{ this.cadenceTypeString }}},
                {{/unless}}
                {{/each}}
                Type<MetadataViews.Display>(),
                Type<FreshmintMetadataViews.BlindNFT>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            {{#if views }}
            if let metadata = self.getMetadata() {
                switch view {
                    {{#each views}}
                    {{> viewCase view=this metadata="metadata" }}
                    {{/each}}
                }

                return nil
            }
            {{ else }}
            if self.getMetadata() != nil {
                return nil
            }
            {{/if}}

            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "{{ contractName }}",
                        description: "This NFT is not yet revealed.",
                        thumbnail: MetadataViews.IPFSFile(
                            cid: {{ contractName }}.placeholderImage, 
                            path: nil
                        )
                    )
                case Type<FreshmintMetadataViews.BlindNFT>():
                    return FreshmintMetadataViews.BlindNFT(metadataHash: self.metadataHash)
                {{#each views}}
                {{#unless this.requiresMetadata }}
                {{> viewCase view=this }}
                {{/unless}}
                {{/each}}
            }

            return nil
        }

        {{#each views}}
        {{#if this.cadenceResolverFunction }}
        {{> (lookup . "id") view=this contractName=../contractName }}
        
        {{/if}}
        {{/each}}
        destroy() {
            {{ contractName }}.totalSupply = {{ contractName }}.totalSupply - (1 as UInt64)

            emit Burned(id: self.id)
        }
    }

    pub resource interface {{ contractName }}CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrow{{ contractName }}(id: UInt64): &{{ contractName }}.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow {{ contractName }} reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: {{ contractName }}CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
        // dictionary of NFTs
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <- token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @{{ contractName }}.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrow{{ contractName }}
        // Gets a reference to an NFT in the collection as a {{ contractName }}.
        //
        pub fun borrow{{ contractName }}(id: UInt64): &{{ contractName }}.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &{{ contractName }}.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let nftRef = nft as! &{{ contractName }}.NFT
            return nftRef as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }

        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Admin
    // Resource that an admin can use to mint NFTs.
    //
    pub resource Admin {

        // mintNFT
        // Mints a new NFT with a new ID
        //
        pub fun mintNFT(metadataHash: [UInt8]): @{{ contractName }}.NFT {
            let nft <- create {{ contractName }}.NFT(metadataHash: metadataHash)

            emit Minted(id: nft.id, metadataHash: metadataHash)

            {{ contractName }}.totalSupply = {{ contractName }}.totalSupply + (1 as UInt64)

            return <- nft
        }

        pub fun revealNFT(id: UInt64, metadata: Metadata) {
            pre {
                {{ contractName }}.metadata[id] == nil : "NFT has already been revealed"
            }

            {{ contractName }}.metadata[id] = metadata

            emit Revealed(id: id)
        }
    }

    // getPublicPath returns a public path that is scoped to this contract.
    //
    pub fun getPublicPath(suffix: String): PublicPath {
        return PublicPath(identifier: "{{ contractName }}_".concat(suffix))!
    }

    // getPrivatePath returns a private path that is scoped to this contract.
    //
    pub fun getPrivatePath(suffix: String): PrivatePath {
        return PrivatePath(identifier: "{{ contractName }}_".concat(suffix))!
    }

    // getStoragePath returns a storage path that is scoped to this contract.
    //
    pub fun getStoragePath(suffix: String): StoragePath {
        return StoragePath(identifier: "{{ contractName }}_".concat(suffix))!
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- {{ contractName }}.createEmptyCollection()

        admin.save(<- collection, to: {{ contractName }}.CollectionStoragePath)

        admin.link<&{{ contractName }}.Collection>({{ contractName }}.CollectionPrivatePath, target: {{ contractName }}.CollectionStoragePath)

        admin.link<&{{ contractName }}.Collection{NonFungibleToken.CollectionPublic, {{ contractName }}.{{ contractName }}CollectionPublic, MetadataViews.ResolverCollection}>({{ contractName }}.CollectionPublicPath, target: {{ contractName }}.CollectionStoragePath)
        
        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init({{#unless saveAdminResourceToContractAccount }}admin: AuthAccount, {{/unless}}placeholderImage: String) {

        self.version = "{{ freshmintVersion }}"

        self.CollectionPublicPath = {{ contractName }}.getPublicPath(suffix: "Collection")
        self.CollectionStoragePath = {{ contractName }}.getStoragePath(suffix: "Collection")
        self.CollectionPrivatePath = {{ contractName }}.getPrivatePath(suffix: "Collection")

        self.AdminStoragePath = {{ contractName }}.getStoragePath(suffix: "Admin")

        self.placeholderImage = placeholderImage

        // Initialize the total supply
        self.totalSupply = 0

        self.metadata = {}

        self.initAdmin(admin: {{#if saveAdminResourceToContractAccount }}self.account{{ else }}admin{{/if}})

        emit ContractInitialized()
    }
}
